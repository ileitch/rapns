require 'unit_spec_helper'
require File.dirname(__FILE__) + '/../app_runner_shared.rb'

describe Rapns::Daemon::Gcm::AppRunner do
  it_behaves_like 'an AppRunner subclass'

  let(:app_class) { Rapns::Gcm::App }
  let(:app) { app_class.new }
  let(:pool) { stub(:async => stub(:deliver => true), :size => 0, :mailbox_size => 0, :terminate => nil, :grow => 0) }
  let(:runner) { Rapns::Daemon::Gcm::AppRunner.new(app) }
  let(:handler) { stub(:start => nil, :stop => nil, :queue= => nil) }
  let(:handler_class) { Rapns::Daemon::Gcm::DeliveryHandler }

  before do
    Rapns::Daemon::Gcm::DeliveryHandler.stub(:new => handler, :pool => pool)
  end
end
