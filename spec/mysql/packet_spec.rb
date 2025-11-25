# frozen_string_literal: true

RSpec.describe MysqlPR::Packet do
  def self.hex(s)
    s.unpack1("H*")
  end

  subject(:packet) { described_class.new(data) }

  describe "#lcb" do
    [
      ["\xfb".b,                                 nil],
      ["\xfc\x01\x02".b,                         0x0201],
      ["\xfd\x01\x02\x03".b,                     0x030201],
      ["\xfe\x01\x02\x03\x04\x05\x06\x07\x08".b, 0x0807060504030201],
      ["\x01".b,                                 0x01],
    ].each do |input_data, result|
      context "for '#{hex(input_data)}'" do
        let(:data) { input_data }

        it { expect(packet.lcb).to eq result }
      end
    end
  end

  describe "#lcs" do
    [
      ["\x03\x41\x42\x43".b, "ABC"],
      ["\x01".b,             ""],
      ["".b,                 nil],
    ].each do |input_data, result|
      context "for '#{hex(input_data)}'" do
        let(:data) { input_data }

        it { expect(packet.lcs).to eq result }
      end
    end
  end

  describe "#read" do
    let(:data) { "ABCDEFGHI".b }

    it { expect(packet.read(7)).to eq "ABCDEFG" }
  end

  describe "#string" do
    let(:data) { "ABC\0DEF".b }

    it "returns NUL terminated String" do
      expect(packet.string).to eq "ABC"
    end
  end

  describe "#utiny" do
    [
      ["\x01".b, 0x01],
      ["\xFF".b, 0xff],
    ].each do |input_data, result|
      context "for '#{hex(input_data)}'" do
        let(:data) { input_data }

        it { expect(packet.utiny).to eq result }
      end
    end
  end

  describe "#ushort" do
    [
      ["\x01\x02".b, 0x0201],
      ["\xFF\xFE".b, 0xfeff],
    ].each do |input_data, result|
      context "for '#{hex(input_data)}'" do
        let(:data) { input_data }

        it { expect(packet.ushort).to eq result }
      end
    end
  end

  describe "#ulong" do
    [
      ["\x01\x02\x03\x04".b, 0x04030201],
      ["\xFF\xFE\xFD\xFC".b, 0xfcfdfeff],
    ].each do |input_data, result|
      context "for '#{hex(input_data)}'" do
        let(:data) { input_data }

        it { expect(packet.ulong).to eq result }
      end
    end
  end

  describe "#eof?" do
    [
      ["\xfe\x00\x00\x00\x00".b, true],
      ["ABCDE".b, false],
    ].each do |input_data, result|
      context "for '#{hex(input_data)}'" do
        let(:data) { input_data }

        it { expect(packet.eof?).to eq result }
      end
    end
  end
end

RSpec.describe "MysqlPR::Packet.lcb" do
  [
    [nil,                  "\xfb".b],
    [1,                    "\x01".b],
    [250,                  "\xfa".b],
    [251,                  "\xfc\xfb\x00".b],
    [65535,                "\xfc\xff\xff".b],
    [65536,                "\xfd\x00\x00\x01".b],
    [16777215,             "\xfd\xff\xff\xff".b],
    [16777216,             "\xfe\x00\x00\x00\x01\x00\x00\x00\x00".b],
    [0xffffffffffffffff,   "\xfe\xff\xff\xff\xff\xff\xff\xff\xff".b],
  ].each do |val, result|
    context "with #{val.inspect}" do
      it { expect(MysqlPR::Packet.lcb(val)).to eq result }
    end
  end
end

RSpec.describe "MysqlPR::Packet.lcs" do
  it { expect(MysqlPR::Packet.lcs("hoge")).to eq "\x04hoge".b }
  it { expect(MysqlPR::Packet.lcs("あいう")).to eq "\x09\xe3\x81\x82\xe3\x81\x84\xe3\x81\x86".b }
end
