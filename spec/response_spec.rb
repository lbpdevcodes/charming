# frozen_string_literal: true

RSpec.describe Charming::Response do
  it "carries a screen name and params for navigation" do
    response = described_class.navigate(:project, id: 5)

    expect(response).to be_navigate
    expect(response.name).to eq(:project)
    expect(response.params).to eq(id: 5)
  end

  it "defaults navigation params to an empty hash" do
    expect(described_class.navigate(:home).params).to eq({})
  end

  it "accepts a bare string screen name" do
    expect(described_class.navigate("project").name).to eq(:project)
  end

  it "raises ArgumentError with a migration hint for a string URL path" do
    expect { described_class.navigate("/projects/5") }
      .to raise_error(ArgumentError, /navigate :projects/)
  end

  it "keeps render and quit responses free of navigation data" do
    expect(described_class.render("hi").name).to be_nil
    expect(described_class.render("hi").params).to eq({})
    expect(described_class.quit.name).to be_nil
    expect(described_class.quit.params).to eq({})
  end
end
