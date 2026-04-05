require "rails_helper"

RSpec.describe PromptProtect::Detectors::IpDetector do
  subject(:detector) { described_class.new(text) }

  describe "#call" do
    context "with an IPv4 address" do
      let(:text) { "Server is at 192.168.1.100" }

      it "returns one finding" do
        expect(detector.call.size).to eq(1)
      end

      it "sets the correct type" do
        expect(detector.call.first[:type]).to eq(:ip)
      end

      it "captures the correct value" do
        expect(detector.call.first[:value]).to eq("192.168.1.100")
      end
    end

    context "with a loopback IPv4 address" do
      let(:text) { "Listening on 127.0.0.1:8080" }

      it "returns one finding" do
        expect(detector.call.size).to eq(1)
      end

      it "captures the address without port" do
        expect(detector.call.first[:value]).to eq("127.0.0.1")
      end
    end

    context "with multiple IPv4 addresses" do
      let(:text) { "From 10.0.0.1 to 10.0.0.254" }

      it "returns two findings" do
        expect(detector.call.size).to eq(2)
      end
    end

    context "with an IPv6 loopback address" do
      let(:text) { "IPv6 loopback is ::1" }

      it "returns one finding" do
        expect(detector.call.size).to eq(1)
      end

      it "sets the correct type" do
        expect(detector.call.first[:type]).to eq(:ip)
      end
    end

    context "with a full IPv6 address" do
      let(:text) { "Address: 2001:0db8:85a3:0000:0000:8a2e:0370:7334" }

      it "returns one finding" do
        expect(detector.call.size).to eq(1)
      end

      it "sets the correct type" do
        expect(detector.call.first[:type]).to eq(:ip)
      end
    end

    context "when text has no IP addresses" do
      let(:text) { "No network info here." }

      it "returns an empty array" do
        expect(detector.call).to be_empty
      end
    end

    context "with an invalid IP-like string" do
      let(:text) { "Version 999.999.999.999 is invalid" }

      it "returns no findings" do
        expect(detector.call).to be_empty
      end
    end
  end
end
