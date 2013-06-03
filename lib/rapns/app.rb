module Rapns
  class App < ActiveRecord::Base
    self.table_name = 'rapns_apps'

    attr_accessible :name, :environment, :certificate, :password, :connections, :auth_key, :rails_env

    has_many :notifications, :class_name => 'Rapns::Notification'

    validates :name, :presence => true, :uniqueness => { :scope => [:type, :environment] }
    validates_numericality_of :connections, :greater_than => 0, :only_integer => true

    validate :certificate_has_matching_private_key

    before_validation :set_rails_env, :on => :create, :unless => :rails_env?

    default_scope { where(:rails_env => Rails.env) }

    private

    def certificate_has_matching_private_key
      result = false
      if certificate.present?
        x509 = OpenSSL::X509::Certificate.new(certificate) rescue nil
        pkey = OpenSSL::PKey::RSA.new(certificate, password) rescue nil
        result = !x509.nil? && !pkey.nil?
        unless result
          errors.add :certificate, 'Certificate value must contain a certificate and a private key.'
        end
      end
      result
    end

    def set_rails_env
      self.rails_env = Rails.env
    end
  end
end
