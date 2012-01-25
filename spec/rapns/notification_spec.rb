require "spec_helper"

describe Rapns::Notification do
  it { should validate_presence_of(:device_token) }
  it { should validate_numericality_of(:badge) }
  it { should validate_numericality_of(:expiry) }

  it "should validate the format of the device_token" do
    notification = Rapns::Notification.new(:device_token => "{$%^&*()}")
    notification.valid?.should be_false
    notification.errors[:device_token].include?("is invalid").should be_true
  end

  it "should validate the length of the binary conversion of the notification" do
    notification = Rapns::Notification.new
    notification.device_token = "a" * 64
    notification.alert = "way too long!" * 100
    notification.valid?.should be_false
    notification.errors[:base].should include("APN notification payload cannot be larger than 256 bytes. Try condensing your alert attribute.")
  end

  it "should default the sound to 1.aiff" do
    Rapns::Notification.new.sound.should == "1.aiff"
  end

  it "should default the expiry to 1 day" do
    Rapns::Notification.new.expiry.should == 1.day.to_i
  end
end

describe Rapns::Notification, "when assigning the device token" do
  it "should strip spaces from the given string" do
    notification = Rapns::Notification.new(:device_token => "o m g")
    notification.device_token.should == "omg"
  end

  it "should strip chevrons from the given string" do
    notification = Rapns::Notification.new(:device_token => "<omg>")
    notification.device_token.should == "omg"
  end
end

describe Rapns::Notification, "when assigning the attributes for the device" do
  it "should raise an ArgumentError if something other than a Hash is assigned" do
    expect { Rapns::Notification.new(:attributes_for_device => Array.new) }.should
      raise_error(ArgumentError, "attributes_for_device must be a Hash")
  end

  it "should encode the given Hash as JSON" do
    notification = Rapns::Notification.new(:attributes_for_device => {:hi => "mom"})
    notification.read_attribute(:attributes_for_device).should == "{\"hi\":\"mom\"}"
  end

  it "should decode the JSON when using the reader method" do
    notification = Rapns::Notification.new(:attributes_for_device => {:hi => "mom"})
    notification.attributes_for_device.should == {"hi" => "mom"}
  end
end

describe Rapns::Notification, "as_json" do
  it "should include the alert if present" do
    notification = Rapns::Notification.new(:alert => "hi mom")
    notification.as_json["aps"]["alert"].should == "hi mom"
  end

  it "should not include the alert key if the alert is not present" do
    notification = Rapns::Notification.new(:alert => nil)
    notification.as_json["aps"].key?("alert").should be_false
  end

  it "should encode the alert as JSON if it is a Hash" do
    notification = Rapns::Notification.new(:alert => { 'body' => "hi mom", 'alert-loc-key' => "View" })
    notification.as_json["aps"]["alert"].should == { 'body' => "hi mom", 'alert-loc-key' => "View" }
  end

  it "should include the badge if present" do
    notification = Rapns::Notification.new(:badge => 6)
    notification.as_json["aps"]["badge"].should == 6
  end

  it "should not include the badge key if the badge is not present" do
    notification = Rapns::Notification.new(:badge => nil)
    notification.as_json["aps"].key?("badge").should be_false
  end

  it "should include the sound if present" do
    notification = Rapns::Notification.new(:alert => "my_sound.aiff")
    notification.as_json["aps"]["alert"].should == "my_sound.aiff"
  end

  it "should not include the sound key if the sound is not present" do
    notification = Rapns::Notification.new(:sound => false)
    notification.as_json["aps"].key?("sound").should be_false
  end

  it "should include attrbutes for the device" do
    notification = Rapns::Notification.new
    notification.attributes_for_device = {:omg => :lol, :wtf => :dunno}
    notification.as_json["omg"].should == "lol"
    notification.as_json["wtf"].should == "dunno"
  end
end

describe Rapns::Notification, "to_binary" do
  it "should correctly convert the notification to binary" do
    notification = Rapns::Notification.new
    notification.device_token = "a" * 64
    notification.sound = "1.aiff"
    notification.badge = 3
    notification.alert = "Don't panic Mr Mainwaring, don't panic!"
    notification.attributes_for_device = {:hi => :mom}
    notification.expiry = 86400 # 1 day, \x00\x01Q\x80
    notification.save!
    notification.stub(:id).and_return(1234)
    notification.to_binary.should == "\x01\x00\x00\x04\xD2\x00\x01Q\x80\x00 \xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA\x00a{\"aps\":{\"alert\":\"Don't panic Mr Mainwaring, don't panic!\",\"badge\":3,\"sound\":\"1.aiff\"},\"hi\":\"mom\"}"
  end
end

describe Rapns::Notification, "bug #31" do
  it 'does not confuse a JSON looking string as JSON' do
    notification = Rapns::Notification.new
    notification.alert = "{\"one\":2}"
    notification.alert.should == "{\"one\":2}"
  end

  it 'does confuse a JSON looking string as JSON if the alert_is_json attribute is not present' do
    notification = Rapns::Notification.new
    notification.stub(:has_attribute? => false)
    notification.alert = "{\"one\":2}"
    notification.alert.should == {"one" => 2}
  end
end

describe Rapns::Notification, "payload size limitation" do
  it "should limit payload size to 256 bytes but not the entire packet" do
    notification = Rapns::Notification.new do |n|
      n.device_token = "a" * 64
      n.alert = "a" * 210
    end

    notification.to_binary(:for_validation => true).size.should > 256
    notification.payload_size.should < 256
    notification.should be_valid
  end
end