require "spec_helper"

describe Lita::State do
  describe "#initialize" do
    it "instatiates" do
      expect(described_class.new).to be_a Lita::State
    end
  end

  let!(:storage) { described_class.new }
  let!(:data) { OpenStruct.new(best_bot: "Litabot!") }

  before :each do
    dat = data
    storage.set(:expensive_key, dat)
  end

  describe "#state" do
    it "returns the state of the storage" do
      expect(storage.get(:expensive_key)).to eq(data)
    end
  end

  describe "#get" do
    it "fetches from that storage with a key" do
      expect(storage.get("expensive_key")).to eq data
    end
  end

  describe "#set" do
    it "sets a value in storage given a key value pair" do
      storage.set("foo", "bar")
      expect(storage.get(:foo)).to eq "bar"
    end
  end

  describe "#synchronize" do
    it "returns the result of the block given" do
      expect(storage.send(:synchronize) { storage.store[:expensive_key].best_bot }).to eq "Litabot!"
    end
  end
end
