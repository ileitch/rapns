module Rapns
  class App < ActiveRecord::Base
    self.table_name = 'rapns_apps'

    attr_accessible :key, :environment, :certificate, :password, :connections

    validates :key, :presence => true, :uniqueness => true
    validates :environment, :presence => true, :inclusion => { :in => %w(development production) }
    validates :certificate, :presence => true
    validates_numericality_of :connections, :greater_than => 0, :only_integer => true
  end
end