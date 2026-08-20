# frozen_string_literal: true

RSpec.describe Charming::Internal::EnvInquirer do
  it "compares equal to its string value" do
    expect(described_class.new("development")).to eq("development")
  end

  it "answers true for the predicate matching its value" do
    expect(described_class.new("test").test?).to be(true)
  end

  it "answers false for predicates that do not match its value" do
    env = described_class.new("test")

    expect(env.development?).to be(false)
    expect(env.production?).to be(false)
  end

  it "responds to any predicate" do
    expect(described_class.new("test")).to respond_to(:staging?)
  end

  it "raises NoMethodError for non-predicate messages" do
    expect { described_class.new("test").frobnicate }.to raise_error(NoMethodError)
  end

  describe "Charming.env integration" do
    after { Charming.env = nil }

    it "defaults to development" do
      Charming.env = nil

      expect(Charming.env).to eq("development")
      expect(Charming.env.development?).to be(true)
    end

    it "reflects an assigned value" do
      Charming.env = "production"

      expect(Charming.env.production?).to be(true)
      expect(Charming.env.development?).to be(false)
    end
  end
end
