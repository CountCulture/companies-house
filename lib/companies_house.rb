# -*- encoding: utf-8 -*-
require 'net/http'
require 'uri'
require 'open-uri'
require 'digest/md5'

require 'morph'
require 'nokogiri'
require 'haml'
require 'yaml'

require File.dirname(__FILE__) + '/companies_house/version'
require File.dirname(__FILE__) + '/companies_house/request'
require File.dirname(__FILE__) + '/companies_house/exception'

$KCODE = 'UTF8' unless RUBY_VERSION >= "1.9"

module CompaniesHouse

  class << self
    
    def company_appointments number, name, options={}
      request :company_appointments, options.merge(:company_number => number, :company_name => name.gsub('&','&amp;'))
    end

    def name_search name, options={}
      request :name_search, options.merge(:company_name => name)
    end

    def number_search number, options={}
      request :number_search, options.merge(:company_number => number)
    end

    def company_details number, options={}
      request :company_details, options.merge(:company_number => number)
    end

    def filing_history number, options={}
      request :filing_history, options.merge(:company_number => number)
    end
    
    def request(request_type, params)
      verbose = params.delete(:verbose)
      xml = CompaniesHouse::Request.request_xml request_type, params
      verbose ? get_response(xml, :verbose => verbose) : get_response(xml)
    end

    def sender_id= id
      @sender_id = id
    end

    def sender_id
      config_setup('.') if @sender_id.blank?
      @sender_id
    end

    def password= pw
      @password = pw
    end

    def password
      config_setup('.') if @password.blank?
      @password
    end

    def email= e
      @email = e
    end

    def email
      @email
    end

    def digest_method
      'CHMD5'
    end

    def create_transaction_id_and_digest(options={})
      transaction_id = (Time.now.to_f * 100).to_i
      digest = Digest::MD5.hexdigest("#{options[:sender_id] || sender_id}#{options[:password] || password}#{transaction_id}")
      return transaction_id, digest
    end

    def config_setup root
      config_file = "#{root}/config/companies-house.yml"
      config_file = "#{root}/companies-house.yml" unless File.exist? config_file
      if File.exist? config_file
        config = YAML.load_file(config_file)
        self.sender_id= config['sender_id']
        self.password= config['password']
        self.email= config['email']
      end
    end

    def objectify response_xml
      doc = Nokogiri::XML(response_xml)
      qualifier = doc.at('Qualifier')
      if qualifier && qualifier.inner_text.to_s[/error/]
        raise_error doc
      else
        body = doc.at('Body')
        if body && body.children.select(&:elem?).size > 0
          objectify_body body
        else
          nil
        end
      end
    end

    private

      def add_to_message attribute, error, message, suffix=''
        if value = error.at(attribute)
          message << "#{value.inner_text}#{suffix}"
        end
      end

      def raise_error doc
        message = []
        if error = doc.at('Error')
          add_to_message 'RaisedBy', error, message
          add_to_message 'Type', error, message
          add_to_message 'Number', error, message, ':'
          add_to_message 'Text', error, message
        end
        raise CompaniesHouse::Exception.new(message.join(' '))
      end

      def objectify_body body
        xml = body.children.select(&:elem?).first.to_s
        hash = Hash.from_xml(xml)
        object = Morph.from_hash(hash, CompaniesHouse)
        if object && object.class.name == 'CompaniesHouse::CompanyDetails'
          if object.respond_to?(:sic_codes)
            sic_codes = object.sic_codes
            if sic_codes.respond_to?(:sic_text) && sic_codes.sic_text
              sic_codes.morph(:sic_texts, [sic_codes.sic_text])
            elsif sic_codes.respond_to?(:sic_texts) && sic_codes.sic_texts
              # leave as is
            else
              object.morph(:sic_codes, Morph.from_hash({:sic_codes => {'sic_texts' => []} }) )
            end
          else
            object.morph(:sic_codes, Morph.from_hash({:sic_codes => {'sic_texts' => []} }) )
          end
        end
        object
      end

      def get_response(data, options={})
        begin
          http = Net::HTTP.new("xmlgw.companieshouse.gov.uk", 80)
          puts "CompaniesHouse request:\n#{data.inspect}" if options[:verbose]
          res, body = http.post("/v1-0/xmlgw/Gateway", data, {'Content-type'=>'text/xml;charset=utf-8'})
          puts "CompaniesHouse response:\n#{res.inspect}" if options[:verbose]
          case res
          when Net::HTTPSuccess, Net::HTTPRedirection
            xml = res.body
            objectify xml
          else
            raise CompaniesHouse::Exception.new(res.inspect.to_s)
          end
        rescue URI::InvalidURIError => e
          raise CompaniesHouse::Exception.new(e.class.name + ' ' + e.to_s)
        rescue SocketError => e
          raise CompaniesHouse::Exception.new(e.class.name + ' ' + e.to_s)
        rescue Timeout::Error => e
          raise CompaniesHouse::Exception.new(e.class.name + ' ' + e.to_s)
        end
      end

  end
end
