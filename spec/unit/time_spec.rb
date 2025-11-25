# frozen_string_literal: true

RSpec.describe MysqlPR::Time do
  describe ".new" do
    it "returns zero values with no arguments" do
      t = described_class.new
      expect(t.year).to eq 0
      expect(t.month).to eq 0
      expect(t.day).to eq 0
      expect(t.hour).to eq 0
      expect(t.minute).to eq 0
      expect(t.second).to eq 0
      expect(t.neg).to eq false
      expect(t.second_part).to eq 0
    end

    it "accepts date and time values" do
      t = described_class.new(2024, 11, 25, 14, 30, 45)
      expect(t.year).to eq 2024
      expect(t.month).to eq 11
      expect(t.day).to eq 25
      expect(t.hour).to eq 14
      expect(t.minute).to eq 30
      expect(t.second).to eq 45
    end
  end

  describe "#to_s" do
    it "formats datetime correctly" do
      t = described_class.new(2009, 12, 8, 23, 35, 21)
      expect(t.to_s).to eq "2009-12-08 23:35:21"
    end

    it "formats time-only correctly" do
      t = described_class.new(0, 0, 0, 12, 30, 45)
      expect(t.to_s).to eq "12:30:45"
    end

    it "formats negative time correctly" do
      t = described_class.new(0, 0, 0, 12, 30, 45, true)
      expect(t.to_s).to eq "-12:30:45"
    end
  end

  describe "#to_i" do
    it "returns integer representation" do
      t = described_class.new(2009, 12, 8, 23, 35, 21)
      expect(t.to_i).to eq 20091208233521
    end
  end

  describe "#inspect" do
    it "returns formatted inspection string" do
      t = described_class.new(2009, 12, 8, 23, 35, 21)
      expect(t.inspect).to eq "#<MysqlPR::Time:2009-12-08 23:35:21>"
    end
  end

  describe "#==" do
    it "returns true for equal times" do
      t1 = described_class.new(2009, 12, 8, 23, 35, 21)
      t2 = described_class.new(2009, 12, 8, 23, 35, 21)
      expect(t1).to eq t2
    end

    it "returns false for different times" do
      t1 = described_class.new(2009, 12, 8, 23, 35, 21)
      t2 = described_class.new(2009, 12, 8, 23, 35, 22)
      expect(t1).not_to eq t2
    end
  end

  describe "attribute accessors" do
    it "allows setting year" do
      t = described_class.new
      t.year = 2024
      expect(t.year).to eq 2024
    end

    it "allows setting month" do
      t = described_class.new
      t.month = 12
      expect(t.month).to eq 12
    end

    it "allows setting day" do
      t = described_class.new
      t.day = 25
      expect(t.day).to eq 25
    end

    it "allows setting hour" do
      t = described_class.new
      t.hour = 14
      expect(t.hour).to eq 14
    end

    it "allows setting minute" do
      t = described_class.new
      t.minute = 30
      expect(t.minute).to eq 30
    end

    it "allows setting second" do
      t = described_class.new
      t.second = 45
      expect(t.second).to eq 45
    end
  end

  describe "aliases" do
    it "has mon as alias for month" do
      t = described_class.new(2024, 11, 25)
      expect(t.mon).to eq t.month
    end

    it "has min as alias for minute" do
      t = described_class.new(0, 0, 0, 14, 30, 45)
      expect(t.min).to eq t.minute
    end

    it "has sec as alias for second" do
      t = described_class.new(0, 0, 0, 14, 30, 45)
      expect(t.sec).to eq t.second
    end
  end
end
