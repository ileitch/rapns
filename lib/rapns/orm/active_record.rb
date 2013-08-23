require 'active_record'

module Rapns
  class RecordBase < ActiveRecord::Base
    self.abstract_class = true
  end
end
