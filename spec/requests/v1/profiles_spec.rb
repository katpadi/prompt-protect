require "rails_helper"

RSpec.describe "GET /v1/profiles", type: :request do
  before { get "/v1/profiles" }

  it "returns 200" do
    expect(response).to have_http_status(:ok)
  end

  it "returns a profiles array" do
    body = JSON.parse(response.body)
    expect(body["profiles"]).to be_an(Array)
  end

  it "includes the default profile" do
    profiles = JSON.parse(response.body)["profiles"]
    expect(profiles).to include(a_hash_including("name" => "default"))
  end

  it "includes the education_basic profile" do
    profiles = JSON.parse(response.body)["profiles"]
    expect(profiles).to include(a_hash_including("name" => "education_basic"))
  end

  it "each profile has a name and description" do
    profiles = JSON.parse(response.body)["profiles"]
    profiles.each do |profile|
      expect(profile).to include("name", "description")
    end
  end

  it "does not expose internal profile keys" do
    profiles = JSON.parse(response.body)["profiles"]
    profiles.each do |profile|
      expect(profile.keys).to match_array(%w[name description])
    end
  end
end
