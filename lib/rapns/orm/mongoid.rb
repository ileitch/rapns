require 'mongoid'
require 'autoinc'

module Rapns
  class RecordBase
    include Mongoid::Document
    include Mongoid::Timestamps
  end
  
  self.config.store = :mongoid
end