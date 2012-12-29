require 'unit_spec_helper'

describe Rapns::Gcm::ActiveRecord::App do
  it { should validate_presence_of(:auth_key) }
end
