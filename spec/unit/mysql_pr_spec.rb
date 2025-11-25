# frozen_string_literal: true

RSpec.describe MysqlPR do
  describe "VERSION" do
    it "returns the version string" do
      expect(described_class::VERSION).to eq "3.0.0"
    end
  end

  describe ".escape_string" do
    it "escapes null bytes" do
      expect(described_class.escape_string("abc\0def")).to eq "abc\\0def"
    end

    it "escapes newlines" do
      expect(described_class.escape_string("abc\ndef")).to eq "abc\\ndef"
    end

    it "escapes carriage returns" do
      expect(described_class.escape_string("abc\rdef")).to eq "abc\\rdef"
    end

    it "escapes backslashes" do
      expect(described_class.escape_string("abc\\def")).to eq "abc\\\\def"
    end

    it "escapes single quotes" do
      expect(described_class.escape_string("abc'def")).to eq "abc\\'def"
    end

    it "escapes double quotes" do
      expect(described_class.escape_string("abc\"def")).to eq "abc\\\"def"
    end

    it "escapes ctrl-z" do
      expect(described_class.escape_string("abc\x1adef")).to eq "abc\\Zdef"
    end

    it "handles complex strings" do
      expect(described_class.escape_string("abc'def\"ghi\0jkl%mno")).to eq "abc\\'def\\\"ghi\\0jkl%mno"
    end

    it "does not escape percent signs" do
      expect(described_class.escape_string("%")).to eq "%"
    end

    it "does not escape underscores" do
      expect(described_class.escape_string("_")).to eq "_"
    end
  end

  describe ".quote" do
    it "is an alias for escape_string" do
      expect(described_class.method(:quote)).to eq described_class.method(:escape_string)
    end
  end

  describe ".client_info" do
    it "returns client version as string" do
      expect(described_class.client_info).to eq "5.0.0"
    end
  end

  describe ".get_client_info" do
    it "is an alias for client_info" do
      expect(described_class.get_client_info).to eq described_class.client_info
    end
  end

  describe ".client_version" do
    it "returns client version as Integer" do
      expect(described_class.client_version).to eq 50000
    end
  end

  describe ".get_client_version" do
    it "is an alias for client_version" do
      expect(described_class.get_client_version).to eq described_class.client_version
    end
  end

  describe ".init" do
    it "returns a MysqlPR object" do
      expect(described_class.init).to be_a MysqlPR
    end

    it "returns an unconnected object" do
      m = described_class.init
      expect(m.protocol).to be_nil
    end
  end
end
