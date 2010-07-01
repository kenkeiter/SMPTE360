require 'packets'
require 'stringio'
require 'pp'

module SMPTE360

  class Stream
    
    attr_accessor :packets
    
    def initialize(path)
      @fp_path = path
      @fp = File.open(path, 'r')
      @packets = []
      map_stream!
    end
    
    def map_stream!
      while @fp.pos != File.size(@fp_path)
        packet = SMPTE360::LazyPacket.new(@fp)
        @packets << packet
        @fp.seek(@fp.pos + packet.length)
      end
    end
    
  end
  
end

str = SMPTE360::Stream.new('../K2_525_MPEG_GOP.gxf')
meta = []
str.packets.map{|p|
  if p.packet_type == 0xfd
    meta << p
  end
}
meta.map{|p|
  puts p.inspect
  #puts p.data.read
  #pp p.data.material
  #pp p.data.tracks
}