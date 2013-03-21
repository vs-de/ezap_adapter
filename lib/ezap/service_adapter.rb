#####
# Copyright 2013, Valentin Schulte, Leipzig
# This File is part of Ezap.
# It is shared to be part of wecuddle from Lailos Group GmbH, Leipzig.
# Before changing or using this code, you have to accept the Ezap License in the Ezap_LICENSE.txt file 
# included in the package or repository received by obtaining this file.
#####
module Ezap
  
  class ServiceAdapter

    #include Ezap::AppConfig
    #default_app_config_name 'ezap_adapter.yml'

    def gm_addr
      #puts app_config
      #app_config[:global_master_address] # || "tcp://127.0.0.1:43691"
      Ezap.config.global_master_address
    end

    attr_reader :adapter_id

    def initialize
      _gm_init
      _locate_service
      sign_on
    end

    def _locate_service
      #print "#{self.class} sign on: "
      resp = _gm_req(:locate_service, self.class.to_s)
      #puts resp.inspect
      addr = resp['address']
      if addr
        _srv_init addr
      else
        raise ("could not locate remote-service: got #{resp.inspect}")
      end
    end

    def sign_on
      @adapter_id = _srv_req :_adp_sign_on
      raise "adapter id: #{@adapter_id.inspect}" unless @adapter_id.is_a?(Fixnum)
    end

    def sign_off
      asw = service_request :_adp_sign_off
      raise "sign off: recvd: #{asw.inspect}" unless is_ack?(asw)
    end

    def _remote_init_model model, *args
      m_id = service_request :_adp_model_init, model.class.top_class_name, *args
      raise "model id: #{m_id.inspect}" unless m_id.is_a?(Fixnum)
      m_id
    end

  #private
    
    def model_list_creation_request _class, req, *args
      list = service_request(req, *args)
      list.map do |hsh|
        r_args = hsh.symbolize_keys!.delete(:args)
        _class.new({service: self}.merge(hsh), *r_args)
      end
    end
    
    #i know, this really looks like a dry candidate...
    def model_creation_request _class, req, *args
      hsh = service_request(req, *args)
      r_args = hsh.symbolize_keys!.delete(:args)
      _class.new({service: self}.merge(hsh), *r_args)
    end
    
    def service_request cmd, *args
      cmd = cmd.to_s.start_with?('_adp') ? cmd : "adp_#{cmd}"
      _srv_req cmd, @adapter_id, *args
      #_srv_req cmd, *args
    end

    def _close_sockets
      @_srv_sock && @_srv_sock.close
      @_gm_sock && @_gm_sock.close
    end

    def _srv_req *args
      _send_req @_srv_sock, *args
    end

    def _gm_req *args
      _send_req @_gm_sock, *args
    end

    def is_ack? asw
      asw.to_s == 'ack'
    end

    def _send_req sock, *args
      sock.send_string(MessagePack.pack(args))
      str = ''
      sock.recv_string(str)
      resp = MessagePack.unpack(str)
      if resp.is_a?(Hash)
        if err = resp['warning']
          $stderr.puts "---remote sent warning: #{err}"
        end
        if err = resp['error']
          raise "remote sent error: #{err}"
        end
      end
      resp
    end
    
    def _gm_init
      @_gm_sock = Ezap::ZMQ_CTX.socket(ZMQ::REQ)
      @_gm_sock.connect(gm_addr)
    end

    def _srv_init addr
      @_srv_addr = addr
      @_srv_sock = Ezap::ZMQ_CTX.socket(ZMQ::REQ)
      puts "connecting..."
      ret = @_srv_sock.connect(addr)
      unless ZMQ::Util.resultcode_ok?(ret)
        msg = ZMQ::Util.error_string
        raise "connect failed: #{msg}"
      end
    end

  end
end
