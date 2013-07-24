module Rapns
  class App < Rapns::RecordBase
    if Rapns.config.store == :active_record
      self.table_name = 'rapns_apps'
    else
      store_in collection: 'rapns_apps'
      
      field :name,        type: String
      field :environment, type: String
      field :certificate, type: String
      field :password,    type: String
      field :connections, type: Integer, default: 1
      field :auth_key,    type: String
      
      has_many :feedbacks, :class_name => 'Rapns::Apns::Feedback'
    end
    
    if Rapns.attr_accessible_available?
      attr_accessible :name, :environment, :certificate, :password, :connections, :auth_key
    end

    has_many :notifications, :class_name => 'Rapns::Notification'

    validates :name, :presence => true, :uniqueness => { :scope => [:type, :environment] }
    validates_numericality_of :connections, :greater_than => 0, :only_integer => true

    validate :certificate_has_matching_private_key

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
  end
end
