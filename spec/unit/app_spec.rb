require 'unit_spec_helper'

describe Rapns::App do
  it 'validates the uniqueness of name within type and environment' do
    Rapns::Apns::App.create!(:name => 'test', :environment => 'production', :certificate => TEST_CERT)
    app = Rapns::Apns::App.new(:name => 'test', :environment => 'production', :certificate => TEST_CERT)
    app.valid?.should be_false
    app.errors[:name].should == ['has already been taken']

    app = Rapns::Apns::App.new(:name => 'test', :environment => 'development', :certificate => TEST_CERT)
    app.valid?.should be_true

    app = Rapns::Gcm::App.new(:name => 'test', :environment => 'production', :auth_key => TEST_CERT)
    app.valid?.should be_true
  end

  it "saves the rails environment" do
    app = Rapns::Apns::App.create!(:name => 'test', :environment => 'production', :certificate => TEST_CERT)
    app.rails_env.should eql 'test'

    app = Rapns::Apns::App.create!(:name => 'test2', :environment => 'production', :certificate => TEST_CERT, :rails_env => 'production')
    app.rails_env.should eql 'production'
  end

  it "has a default scope to load only the apps in the rails environment" do
    Rapns::App.scoped.to_sql.should eql Rapns::App.where(:rails_env => Rails.env).to_sql
  end

end
