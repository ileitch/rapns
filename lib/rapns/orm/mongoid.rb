require 'mongoid'
require 'autoinc'

module Rapns
  class RecordBase
    include Mongoid::Document
    include Mongoid::Timestamps
    
    store_in collection: 'rapns'
  end
  
  self.config.store = :mongoid
end