# frozen_string_literal: true

class MysqlPR
  # Binary packet parsing for MySQL protocol
  class Packet
    # convert Numeric to LengthCodedBinary
    def self.lcb(num)
      return "\xfb".b if num.nil?
      return [num].pack("C") if num < 251
      return [252, num].pack("Cv") if num < 65_536
      return [253, num & 0xffff, num >> 16].pack("CvC") if num < 16_777_216

      [254, num & 0xffffffff, num >> 32].pack("CVV")
    end

    # convert String to LengthCodedString
    def self.lcs(str)
      str = Charset.to_binary str
      lcb(str.length) + str
    end

    def initialize(data)
      @data = data
    end

    def lcb
      return nil if @data.empty?

      case v = utiny
      when 0xfb
        nil
      when 0xfc
        ushort
      when 0xfd
        c = utiny
        v = ushort
        (v << 8) + c
      when 0xfe
        v1 = ulong
        v2 = ulong
        (v2 << 32) + v1
      else
        v
      end
    end

    def lcs
      len = lcb
      return nil unless len

      @data.slice!(0, len)
    end

    def read(len)
      @data.slice!(0, len)
    end

    def string
      str = @data.unpack1("Z*")
      @data.slice!(0, str.length + 1)
      str
    end

    def utiny
      @data.slice!(0, 1).unpack1("C")
    end

    def ushort
      @data.slice!(0, 2).unpack1("v")
    end

    def ulong
      @data.slice!(0, 4).unpack1("V")
    end

    def eof?
      @data.getbyte(0) == 0xfe && @data.length == 5
    end

    def to_s
      @data
    end
  end
end
