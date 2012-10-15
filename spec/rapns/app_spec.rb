require "spec_helper"


# a test certificate that contains both an X509 certificate and
# a private key, similar to those used for connecting to Apple
# push notification servers.
#
# Note that we cannot validate the certificate and private key
# because we are missing the certificate chain used to validate
# the certificate, and this is private to Apple. So if the app
# has a certificate and a private key in it, the only way to find
# out if it really is valid is to connect to Apple's servers.
#
TEST_CERT = <<EOF
Bag Attributes
    friendlyName: test certificate
    localKeyID: 00 93 8F E4 A3 C3 75 64 3D 7E EA 14 0B 0A EA DD 15 85 8A D5
subject=/CN=test certificate/O=Example/OU=Example/ST=QLD/C=AU/L=Example/emailAddress=user@example.com
issuer=/CN=test certificate/O=Example/OU=Example/ST=QLD/C=AU/L=Example/emailAddress=user@example.com
-----BEGIN CERTIFICATE-----
MIID5jCCAs6gAwIBAgIBATALBgkqhkiG9w0BAQswgY0xGTAXBgNVBAMMEHRlc3Qg
Y2VydGlmaWNhdGUxEDAOBgNVBAoMB0V4YW1wbGUxEDAOBgNVBAsMB0V4YW1wbGUx
DDAKBgNVBAgMA1FMRDELMAkGA1UEBhMCQVUxEDAOBgNVBAcMB0V4YW1wbGUxHzAd
BgkqhkiG9w0BCQEWEHVzZXJAZXhhbXBsZS5jb20wHhcNMTIwOTA5MDMxODMyWhcN
MjIwOTA3MDMxODMyWjCBjTEZMBcGA1UEAwwQdGVzdCBjZXJ0aWZpY2F0ZTEQMA4G
A1UECgwHRXhhbXBsZTEQMA4GA1UECwwHRXhhbXBsZTEMMAoGA1UECAwDUUxEMQsw
CQYDVQQGEwJBVTEQMA4GA1UEBwwHRXhhbXBsZTEfMB0GCSqGSIb3DQEJARYQdXNl
ckBleGFtcGxlLmNvbTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAKF+
UDsN1sLen8g+97PNTiWju9+wkSv+H5rQlvb6YFLPx11YvqpK8ms6kFU1OmWeLfmh
cpsT+bZtKupC7aGPoSG3RXzzf/YUMgs/ZSXA0idZHA6tkReAEzIX6jL5otfPWbaP
luCTUoVMeP4u9ywk628zlqh9IQHC1Agl0R1xGCpULDk8kn1gPyEisl38wI5aDbzy
6lYQGNUKOqt1xfVjtIFe/jyY/v0sxFjIJlRLcAFBuJx4sRV+PwRBkusOQtYwcwpI
loMxJj+GQe66ueATW81aC4iOU66DAFFEuGzwIwm3bOilimGGQbGb92F339RfmSOo
TPAvVhsakI3mzESb4lkCAwEAAaNRME8wDgYDVR0PAQH/BAQDAgeAMCAGA1UdJQEB
/wQWMBQGCCsGAQUFBwMCBggrBgEFBQcDATAbBgNVHREEFDASgRB1c2VyQGV4YW1w
bGUuY29tMA0GCSqGSIb3DQEBCwUAA4IBAQA5UbNR+83ZdI2DiaB4dRmy0V5RDAqJ
k9+QskcTV4gBTjsOBS46Dw1tI6iTrfTyjYJdnyH0Y2Y2YVWBnvtON41UCZak+4ed
/IqyzU0dtfZ+frWa0RY4reyl80TwqnzyJfni0nDo4zGGvz70cxyaz2u1BWqwLjqb
dh8Dxvt+aHW2MQi0iGKh/HNbgwVanR4+ubNwziK9sR1Rnq9MkHWtwBw16SXQG6ao
SZKASWNaH8VL08Zz0E98cwd137UJkPsldCwJ8kHR5OzkcjPdXvnGD3d64yy2TC1Z
Gy1Aazt98wPcTYBytlhK8Rvzg9OoY9QmsdpmWxz1ZCXECJNqCa3IKsqO
-----END CERTIFICATE-----
Bag Attributes
    friendlyName: test certificate
    localKeyID: 00 93 8F E4 A3 C3 75 64 3D 7E EA 14 0B 0A EA DD 15 85 8A D5
Key Attributes: <No Attributes>
-----BEGIN RSA PRIVATE KEY-----
MIIEpQIBAAKCAQEAoX5QOw3Wwt6fyD73s81OJaO737CRK/4fmtCW9vpgUs/HXVi+
qkryazqQVTU6ZZ4t+aFymxP5tm0q6kLtoY+hIbdFfPN/9hQyCz9lJcDSJ1kcDq2R
F4ATMhfqMvmi189Zto+W4JNShUx4/i73LCTrbzOWqH0hAcLUCCXRHXEYKlQsOTyS
fWA/ISKyXfzAjloNvPLqVhAY1Qo6q3XF9WO0gV7+PJj+/SzEWMgmVEtwAUG4nHix
FX4/BEGS6w5C1jBzCkiWgzEmP4ZB7rq54BNbzVoLiI5TroMAUUS4bPAjCbds6KWK
YYZBsZv3YXff1F+ZI6hM8C9WGxqQjebMRJviWQIDAQABAoIBAQCTiLIDQUFSBdAz
QFNLD+S0vkCEuunlJuP4q1c/ir006l1YChsluBJ/o6D4NwiCjV+zDquEwVsALftm
yH4PewfZpXT2Ef508T5GyEO/mchj6iSXxDkpHvhqay6qIyWBwwxSnBtaTzy0Soi+
rmlhCtmLXbXld2sQEM1kJChGnWtWPtvSyrn+mapNPZviGRtgRNK+YsrAti1nUext
2syO5mTdHf1D8GR7I98OaX6odREuSocEV9PzfapWZx2GK5tvRiS1skiug5ciieTd
Am5/C+bb31h4drFslihLb5BRGO5SFQJvMJL2Sx1f19BCC4XikS01P4/zZbxQNq79
kxEQuDGBAoGBANP4pIYZ5xshCkx7cTYqmxzWLClGKE2S7Oa8N89mtOwfmqT9AFun
t9Us9Ukbi8BaKlKhGpQ1HlLf/KVcpyW0x2qLou6AyIWYH+/5VaR3graNgUnzpK9f
1F5HoaNHbhlAoebqhzhASFlJI2aqUdQjdOv73z+s9szJU4gpILNwGDFnAoGBAMMJ
j+vIxtG9J2jldyoXzpg5mbMXSj9u/wFLBVdjXWyOoiqVMMBto53RnoqAom7Ifr9D
49LxRAT1Q3l4vs/YnM3ziMsIg2vQK1EbrLsY9OnD/kvPaLXOlNIOdfLM8UeVWZMc
I4LPbbZrhv/7CC8RjbRhMoWWdGYPvxmvD6V4ZDY/AoGBALoI6OxA45Htx4okdNHj
RstiNNPsnQaoQn6nBhxiubraafEPkzbd1fukP4pwQJELEUX/2sHkdL6rkqLW1GPF
a5dZAiBsqpCFWNJWdBGqSfBJ9QSgbxLz+gDcwUH6OOi0zuNJRm/aCyVBiW5bYQHc
NIvAPMk31ksZDtTbs7WIVdNVAoGBALZ1+KWNxKqs+fSBT5UahpUUtfy8miJz9a7A
/3M8q0cGvSF3Rw+OwpW/aEGMi+l2OlU27ykFuyukRAac9m296RwnbF79TO2M5ylO
6a5zb5ROXlWP6RbE96b4DlIidssQJqegmHwlEC+rsrVBpOtb0aThlYEyOxzMOGyP
wOR9l8rDAoGADZ4TUHFM6VrvPlUZBkGbqiyXH9IM/y9JWk+22JQCEGnM6RFZemSs
jxWqQiPAdJtb3xKryJSCMtFPH9azedoCrSgaMflJ1QgoXgpiKZyoEXWraVUggh/0
CEavgZcTZ6SvMuayqJdGGB+zb1V8XwXMtCjApR/kTm47DjxO4DmpOPs=
-----END RSA PRIVATE KEY-----
EOF


describe Rapns::App do

  it "does not validate an app with an invalid certificate" do
    @app = Rapns::App.new :key => 'test', :environment => 'development', :certificate => 'foo'
    @app.should_not be_valid
    @app.errors.should include(:certificate)
  end

  it "does validate a real certificate" do
    @app = Rapns::App.new :key => 'test', :environment => 'development', :certificate => TEST_CERT
    @app.should be_valid
  end
end
