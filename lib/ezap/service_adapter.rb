#####
# Copyright 2013, Valentin Schulte, Leipzig, Germany
# This file is part of Ezap.
# Ezap is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 3 
# as published by the Free Software Foundation.
# You should have received a copy of the GNU General Public License
# in the file COPYING along with Ezap. If not, see <http://www.gnu.org/licenses/>.
#####

module Ezap
  
  module ServiceAdapter

    #include Ezap::AppConfig
    #default_app_config_name 'ezap_adapter.yml'

    def gm_addr
      #puts app_config
      #app_config[:global_master_address] # || "tcp://127.0.0.1:43691"
      Ezap.config.global_master_address
    end

    attr_reader :adapter_id
    attr_accessor :service_name

    def initialize opts={}
      opts = {service_name: self.class.to_s}.merge!(opts)
      self.service_name = opts[:service_name]
      _gm_init
      _locate_service
      sign_on
    end

    def _locate_service
      #print "#{self.class} sign on: "
      resp = _gm_req(:locate_service, service_name)
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
      raise "strange adapter id: #{@adapter_id.inspect}" unless @adapter_id.is_a?(Fixnum)
    end

    def sign_off
      asw = service_request :_adp_sign_off
      raise "sign off: recvd: #{asw.inspect}" unless is_ack?(asw)
    end

    def _remote_init_model model, *args
      m_id = service_request :_adp_model_init, model.class.top_class_name, *args
      raise "strange model id: #{m_id.inspect}" unless m_id.is_a?(Fixnum)
      m_id
    end

    def _remote_model_send model, *args
      service_request :_adp_model_send, model.class.top_class_name, model.m_id, *args
    end
    

    def model_blue_print model_class
      return <<SRC
class #{service_name}
#{model_class.remote_blue_print.gsub(/^/,'  ')}
end
SRC
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
    
    #as we all know: eval is evil, use with care
    def _remote_eval cmd
      _srv_req :_eval, cmd
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
      @_gm_sock = Ezap::ZmqCtx().socket(ZMQ::REQ)
      @_gm_sock.connect(gm_addr)
    end

    def _srv_init addr
      @_srv_addr = addr
      @_srv_sock = Ezap::ZmqCtx().socket(ZMQ::REQ)
      puts "connecting..."
      ret = @_srv_sock.connect(addr)
      unless ZMQ::Util.resultcode_ok?(ret)
        msg = ZMQ::Util.error_string
        raise "connect failed: #{msg}"
      end
    end

  end
end
