require "rails_helper"

RSpec.describe PromptProtect::Profiles::Registry do
  describe ".find" do
    it "returns the default profile" do
      profile = described_class.find("default")
      expect(profile[:name]).to eq("default")
      expect(profile[:policy_overrides]).to eq({})
      expect(profile[:restore_output]).to be false
    end

    it "returns the lenient profile" do
      profile = described_class.find("lenient")
      expect(profile[:name]).to eq("lenient")
      expect(profile[:policy_overrides]).to eq({ high: :sanitize })
      expect(profile[:restore_output]).to be true
    end

    it "raises ArgumentError for unknown profiles" do
      expect { described_class.find("nonexistent") }.to raise_error(ArgumentError, /Unknown profile/)
    end
  end

  describe ".all" do
    it "returns an array of profile summaries" do
      profiles = described_class.all
      expect(profiles).to be_an(Array)
      names = profiles.map { |p| p[:name] }
      expect(names).to include("default", "lenient")
    end

    it "includes only name and description (no internal keys)" do
      described_class.all.each do |profile|
        expect(profile.keys).to contain_exactly(:name, :description)
      end
    end

    it "includes descriptions for all profiles" do
      described_class.all.each do |profile|
        expect(profile[:description]).to be_a(String).and be_present
      end
    end
  end
end
