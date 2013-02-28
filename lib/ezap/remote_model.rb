#####
# Copyright 2013, Valentin Schulte, Leipzig
# This File is part of Ezap.
# It is shared to be part of wecuddle from Lailos Group GmbH, Leipzig.
# Before changing or using this code, you have to accept the Ezap License in the Ezap_LICENSE.txt file 
# included in the package or repository received by obtaining this file.
#####

module Ezap

  class RemoteModel
    #rpc methods
    @@rpc_ms = {}

    #cache methods
    #not implemented yet
    @@cache_ms = {}
   
    #this file has some crude hacked magic

    attr_accessor :service
    attr_reader :m_id
    def __initialize opts, *args
      @service = opts[:service]
      unless @service.is_a?(ServiceAdapter)
        raise "an instance of #{self.class} should only be produced by a ServiceAdapter" 
      end
      __orig_initialize(*args)
      _zmq_init()
      @m_id = opts[:m_id] || @service._remote_init_model(self, *args)
      #_sign_on
    end

    def self.proxy_call *args
      puts "proxy call: #{args.inspect}"
    end

    ############
    #annotations
    ############

    def self.methods_are *args
      unless @__annotate_defaults
        @__annotate_defaults = args
        return
      end
      arr = args.map(&:to_sym)
      arr.each do |s|
        i = @__annotate_defaults.find_index(s) || @__annotate_defaults.find_index(ANNOTATIONS[s])
        unless i
          $stderr.puts "\n---warning: no annotation of name #{s} defined\n"
          next
        end
        @__annotate_defaults[i] = s
      end
      #puts "new setting: #{@__annotate_defaults}"
    end

    #default
    methods_are :remote, :cached

    @__m_next = []
    @__m_hook_skip = []
    def self.inherited base
      base.methods_are(:remote, :cached)
      base.instance_variable_set(:@__m_next, [])
      base.instance_variable_set(:@__m_hook_skip, [])
    end

    #binary annotions
    ANNOTATIONS = lambda{|h|h.merge!(h.invert)}.call(local: :remote, cached: :uncached)
    #[:local, :remote, :cached, :uncached].each{|flag| define_method(flag)}
    
    def self.annotate ann
      o=Object.new
      def o.+@();end
      @__m_next << ann
      o
    end

    def self.local
      annotate(:local)
    end

    def self.remote
      annotate(:remote)
    end

    def self.cached
      annotate(:cached)
    end

    def self.uncached
      annotate(:uncached)
    end

    ##################
    #annotation hooks#
    ##################

    #TODO: that "self"-usage inside the block might be dangerous and not have this meaning in future ruby versions
    def self.__act_remote m
      (@@rpc_ms[self] ||= [])  << m
      new_m = :"__m_orig_#{m}"
      @__m_hook_skip.push(new_m)
      alias_method new_m, m
      #@__m_hook_skip.push(m)
      Ezap::RemoteModel.instance_variable_get("@__m_hook_skip").push(m)
      Ezap::RemoteModel.send(:define_method, m) do |*args|
        self.class.proxy_call self, *args
      end
    end

    def self.__act_local m

    end

    def self.__act_cached m
      (@@cache_ms[self] ||= []) << m
    end

    def self.__act_uncached m
    end

    ##################
    ##################

    def self.rpc_methods
      @@rpc_ms[self]
    end

    def self.cache_methods
      @@cache_ms[self]
    end

    def self.top_class_name
      self.to_s.gsub(/.*::/,'')
    end

    #meta/export func
    #this is special. "prints" the needed remote-class
    def self.remote_blue_print
      name = top_class_name
      str = "class #{name} < Ezap::Service::Base::ServiceObject\n"
      rpc_methods.each {|m|str << "\n  def #{m}\n\n  end\n"}
      str << "\nend"
    end

    def inspect
      "<#{self.class}: m_id: #{m_id}, adapter: #{service.class}>"
    end

    private

    def _zmq_init
      @z_sock = Ezap::ZMQ_CTX.socket(ZMQ::REQ)
    end

    def self.wrap_initializer
      @__m_hook_skip << :__orig_initialize
      alias_method(:__orig_initialize, :initialize)
      @__m_hook_skip << :initialize
      alias_method(:initialize, :__initialize)

    end

    #!
    #keep that as the last definition, so that it's not triggered by itself
    #!
    def self.method_added m
      return if @__m_hook_skip.pop == m
      if m == :initialize
        wrap_initializer
        return
      end
      @__annotate_defaults.each do |ann|
        f = @__m_next.delete(ANNOTATIONS[ann]) || ann
        send("__act_#{f}", m)
      end
    end
  end

end
