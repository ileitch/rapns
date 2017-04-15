module Rapns
  class App < ActiveRecord::Base
    self.table_name = 'rapns_apps'

    if Rapns.attr_accessible_available?
      attr_accessible :name, :environment, :certificate, :password, :connections, :auth_key, :client_id, :client_secret
    end

    has_many :notifications, :class_name => 'Rapns::Notification', :dependent => :destroy

    validates :name, :presence => true
    validates_numericality_of :connections, :greater_than => 0, :only_integer => true

    def service_name
      raise NotImplementedError
    end
  end
end
