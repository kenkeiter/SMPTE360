module SMPTE360
  
  class PacketFormatError < StandardError
    
    attr_reader :reason
    
    def initialize(reason)
      @reason = reason
    end
    
  end
  
end