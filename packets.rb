require 'exceptions'
require 'stringio'

module SMPTE360
  
  PACKETTYPE_MAP = 0xbc
  PACKETTYPE_MEDIA = 0xbf
  PACKETTYPE_EOS = 0xfb # end of stream
  PACKETTYPE_FLT = 0xfc # field locator table
  PACKETTYPE_UMF = 0xfd
  
  UMF_INTERMEDIATEPACKET = 0
  UMF_FIRSTPACKET = 1
  UMF_LASTPACKET = 2
  UMF_ONLYPACKET = 3
  
  class LazyPacket
    
    attr_reader :length, :packet_type
    
    def initialize(fp)
      @fp, @offset = fp, fp.pos
      @packet_type, @original_length = parse_header(@fp.read(16))
      @length = @original_length
      @fp.seek(@offset) # rewind to start of packet
    end
    
    def parse_header(hdata)
      if @packet_type.nil?
        unless hdata[0x00..0x04] == "\x00\x00\x00\x00\x01"
          raise SMPTE360::PacketFormatError.new('Invalid packet leader.')
        end
        return [hdata[0x05], hdata[0x06..0x09].unpack('N')[0]]
      end
      return @packet_type, @packet_length
    end
    
    def data
      if @data.nil?
        @fp.seek(@offset + 16)
        raw_data = StringIO.new(@fp.read(@length - 16))
        @data = case @packet_type
          when PACKETTYPE_MAP then MapPacketType.new(raw_data)
          when PACKETTYPE_UMF then UMFPacketType.new(raw_data)
          else raw_data.read
        end
        @fp.seek(@offset) # rewind to start of packet
      end
      return @data
    end
    
    def data=(new_data)
      @new_length = new_data.length + 16
      @data = new_data
    end
    
    def pack
      # leader | type | length | value | reserved | trailer
      header = [0x01, @packet_type, @new_length, @data, "\x00\x00\x00\x00\xe1\xe2"]
      header.pack('xxxxCCNAA')
    end
    
  end
  
  class MapPacketType

    attr_accessor :tracks, :material

    def initialize(data)
      @data = data
      @material, @tracks = [], []
      unless @data.read(2) == "\xe0\xff"
        raise SMPTE360::PacketFormatError('Corrupt map packet preamble.')
      end
      unpack!
    end

    def pack
      
    end
    
    #######
    private
    #######
    
    def unpack!
      # read material descriptors
      material_length, material_start = @data.read(2).unpack('n')[0], @data.pos
      while @data.pos < material_start + material_length
        @material << read_descriptor!(0x40..0x4B)
      end
      
      # read track descriptors
      track_section_length, track_section_start = @data.read(2).unpack('n')[0], @data.pos
      while @data.pos < track_section_start + track_section_length
        track = {}
        track[:media_type] = @data.read(1).unpack('C')[0]
        track[:id] = @data.read(1).unpack('C')[0]
        track[:length] = @data.read(2).unpack('n')[0]
        track_descriptor_start_pos = @data.pos
        track[:descriptors] = []
        while @data.pos < track_descriptor_start_pos + track[:length]
          descriptor = read_descriptor!(0x4c..0x52)
          break if descriptor.nil?
          track[:descriptors] << descriptor
        end
        @tracks << track
      end
    end
    
    def read_descriptor!(valid_tags)
      descriptor = {}
      descriptor[:tag] = @data.read(1).unpack('C')[0]
      descriptor[:length] = @data.read(1).unpack('C')[0]
      descriptor[:value] = @data.read(descriptor[:length])
      return nil unless valid_tags.include? descriptor[:tag]
      return descriptor
    end
    
  end
  
  class UMFPacketType
    
    def initialize(data)
      @data, @order = data, data.read(1).unpack('C')[0]
      @length = data.read(4).unpack('N')[0]
      @payload_description = parse_payload_desc!
      @material_description = parse_material_desc!
      @track_description = parse_track_desc!
      @media_description = parse_media_desc!
    end
    
    #######
    private
    #######
    
    def parse_payload_desc!
      payload = {}
      fields = [
        :length, :version, :track_count, :track_desc_offset, 
        :segment_count, :media_desc_offset, :media_desc_length, 
        :user_data_offset, :user_data_length, :reserved_1, :reserved_2
      ]
      field_values = data.read(fields.length * 4).unpack('N' * fields.length)
      fields.zip(field_values).each{|k, v| payload[k] = v}
      return payload
    end
    
    def parse_material_desc!
      material_desc = {}
      fields = [
        :material_attributes, :max_field_length, :min_field_length, 
        :mark_in, :mark_out, :mark_in_timecode, :mark_out_timecode, 
        :last_modified_msb, :last_modified_lsb, :create_time_msb, 
        :create_time_lsb, :reserved_1, :reserved_2, :audio_track_count,
        :timecode_track_count, :reserved_3, :mpeg_track_count
      ]
      field_values = data.read(56).unpack('N' * 11 + 'n' * 6)
      fields.zip(field_values).each{|k, v| material_desc[k] = v}
    end
    
    def parse_track_desc!
      tracks = []
      start_pos, bytes_per_desc = @data.pos, 2
      while @data.pos < @payload_description[:track_count] * bytes_per_desc
        tracks << @data.read(2).unpack('nn')
      end
      return tracks
    end
    
    def parse_media_desc!
      media = []
      fields = [
        :length, :track_info, :media_seq_num, :reserved_1, :segment_field_count, 
        :reserved_2, :mark_in, :mark_out, :source_device_filename, :media_type, 
        :sampling_rate, :sampling_size, :reserved_3
      ]
    end
    
    def 
    
  end
  
end