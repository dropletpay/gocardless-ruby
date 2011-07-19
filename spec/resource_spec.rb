require 'spec_helper'

describe Grapi::Resource do
  it "initializes from hash" do
    test_resource = Class.new(Grapi::Resource) do
      attr_accessor :id, :name, :uri
    end
    props = {:id => 1, :name => 'test', :uri => 'http://test'}
    resource = test_resource.from_hash(mock, props)
    props.each { |k,v| resource.send(k).should == v }
  end

  describe "#date_writer" do
    it "creates date writers properly" do
      test_resource = Class.new(Grapi::Resource) do
        date_writer :created_at, :modified_at
      end

      test_resource.instance_methods.should include 'created_at='
      test_resource.instance_methods.should include 'modified_at='
    end

    it "date writers work properly" do
      test_resource = Class.new(Grapi::Resource) do
        date_writer :created_at
      end

      resource = test_resource.new(nil)
      time = '2011-12-12T12:00:00Z'
      resource.created_at = time
      date_time = resource.instance_variable_get(:@created_at)
      date_time.should be_instance_of DateTime
      date_time.strftime('%Y-%m-%dT%H:%M:%SZ').should == time
    end
  end

  describe "#date_accessor" do
    it "creates date readers and writers properly" do
      test_resource = Class.new(Grapi::Resource) do
        date_accessor :created_at, :modified_at
      end

      test_resource.instance_methods.should include 'created_at='
      test_resource.instance_methods.should include 'created_at'
      test_resource.instance_methods.should include 'modified_at='
      test_resource.instance_methods.should include 'modified_at'
    end

    it "date readers work properly" do
      test_resource = Class.new(Grapi::Resource) do
        date_accessor :created_at
      end

      resource = test_resource.new(nil)
      date = DateTime.now
      resource.instance_variable_set(:@created_at, date)
      resource.created_at.should == date
    end
  end

  describe "#find" do
    it "instantiates the correct object" do
      test_resource = Class.new(Grapi::Resource) do
        ENDPOINT = '/test/:id'
      end
      mock_client = mock
      mock_client.expects(:api_get).returns({:id => 123})
      resource = test_resource.find(mock_client, 123)
      resource.should be_a test_resource
      resource.id.should == 123
    end
  end

  describe "#reference_writer" do
    it "creates reference writers properly" do
      test_resource = Class.new(Grapi::Resource) do
        reference_writer :merchant_id, :user_id
      end

      test_resource.instance_methods.should include 'merchant='
      test_resource.instance_methods.should include 'merchant_id='
      test_resource.instance_methods.should include 'user='
      test_resource.instance_methods.should include 'user_id='
    end

    it "direct assignment methods work properly" do
      test_resource = Class.new(Grapi::Resource) do
        reference_writer :user_id
      end

      resource = test_resource.new(nil)
      resource.user = Grapi::User.from_hash(nil, :id => 123)
      resource.instance_variable_get(:@user_id).should == 123
    end

    it "requires args to end with _id" do
      expect do
        test_resource = Class.new(Grapi::Resource) do
          reference_writer :user
        end
      end.to raise_exception ArgumentError
    end

    it "fails with the wrong object type" do
      test_resource = Class.new(Grapi::Resource) do
        reference_writer :user_id
      end
      expect do
        test_resource.new(nil).user = 'asdf'
      end.to raise_exception ArgumentError
    end
  end

  describe "#reference_reader" do
    before :each do
      @app_id = 'abc'
      @app_secret = 'xyz'
      @client = Grapi::Client.new(@app_id, @app_secret)
      @redirect_uri = 'http://test.com/cb'
    end

    it "creates reference writers properly" do
      test_resource = Class.new(Grapi::Resource) do
        reference_reader :merchant_id, :user_id
      end

      test_resource.instance_methods.should include 'merchant'
      test_resource.instance_methods.should include 'merchant_id'
      test_resource.instance_methods.should include 'user'
      test_resource.instance_methods.should include 'user_id'
    end

    it "lookup methods work properly" do
      test_resource = Class.new(Grapi::Resource) do
        reference_reader :user_id
      end

      resource = test_resource.new(@client)
      resource.instance_variable_set(:@user_id, 123)
      stub_get(@client, {:id => 123})
      user = resource.user
      user.should be_a Grapi::User
      user.id.should == 123
    end

    it "requires args to end with _id" do
      expect do
        test_resource = Class.new(Grapi::Resource) do
          reference_reader :user
        end
      end.to raise_exception ArgumentError
    end
  end

  describe "#reference_accessor" do
    it "creates reference readers and writers" do
      test_resource = Class.new(Grapi::Resource) do
        reference_accessor :merchant_id, :user_id
      end

      test_resource.instance_methods.should include 'merchant'
      test_resource.instance_methods.should include 'merchant_id'
      test_resource.instance_methods.should include 'user'
      test_resource.instance_methods.should include 'user_id'
      test_resource.instance_methods.should include 'merchant='
      test_resource.instance_methods.should include 'merchant_id='
      test_resource.instance_methods.should include 'user='
      test_resource.instance_methods.should include 'user_id='
    end
  end

  it "#persisted? works" do
    Grapi::Resource.new(nil).persisted?.should be_false
    Grapi::Resource.from_hash(nil, :id => 1).persisted?.should be_true
  end

  describe "#save" do
    describe "succeeds and" do
      before :each do
        @test_resource = Class.new(Grapi::Resource) do
          attr_accessor :x, :y
          creatable
          updatable
        end
      end

      after :each do
        @test_resource = nil
      end

      it "sends the correct data parameters" do
        client = mock
        data = {:x => 1, :y => 2}
        resource = @test_resource.from_hash(client, data)
        client.expects(:api_post).with do |path, params|
          params.should == data
        end
        resource.save
      end

      it "sends the correct path" do
        client = mock
        @test_resource::ENDPOINT = '/test'
        resource = @test_resource.new(client)
        client.expects(:api_post).with do |path, params|
          path.should == '/test'
        end
        resource.save
      end

      it "POSTs when not persisted" do
        client = mock
        resource = @test_resource.new(client)
        client.expects(:api_post)
        resource.save
      end

      it "PUTs when already persisted" do
        client = mock
        resource = @test_resource.from_hash(client, :id => 1)
        client.expects(:api_put)
        resource.save
      end
    end

    it "succeeds when not persisted and create allowed" do
      test_resource = Class.new(Grapi::Resource) do
        creatable
      end

      client = mock('client') { stubs :api_post }
      test_resource.new(client).save
    end

    it "succeeds when persisted and update allowed" do
      test_resource = Class.new(Grapi::Resource) do
        updatable
      end

      client = mock('client') { stubs :api_put }
      test_resource.from_hash(client, :id => 1).save
    end

    it "fails when not persisted and create not allowed" do
      test_resource = Class.new(Grapi::Resource) do
        updatable
      end

      expect { test_resource.new(mock).save }.to raise_error
    end

    it "fails when persisted and update not allowed" do
      test_resource = Class.new(Grapi::Resource) do
        creatable
      end

      expect { test_resource.from_hash(mock, :id => 1).save }.to raise_error
    end
  end

  it "#to_hash pulls out the correct attributes" do
    test_resource = Class.new(Grapi::Resource) do
      attr_accessor :x
    end

    attrs = {:id => 1, :uri => 'http:', :x => 'y'}
    resource = test_resource.from_hash('CLIENT', attrs)
    resource.to_hash.should == attrs
  end

  it "#to_json converts to the correct JSON format" do
    test_resource = Class.new(Grapi::Resource) do
      attr_accessor :amount
      date_accessor :when
      reference_accessor :person_id
    end

    bill = test_resource.from_hash(nil, {
      :amount => 10,
      :when => DateTime.now,
      :person_id => 15
    })

    result = JSON.parse(bill.to_json)
    result['amount'].should == bill.amount
    result['when'].should == bill.when.to_s
    result['person_id'].should == 15
  end

  describe "resource permissions" do
    it "are not given by default" do
      Grapi::Resource.creatable?.should be_false
      Grapi::Resource.updatable?.should be_false
    end

    it "are present when specified" do
      class CreatableResource < Grapi::Resource
        creatable
      end

      class UpdatableResource < Grapi::Resource
        updatable
      end

      CreatableResource.creatable?.should be_true
      CreatableResource.updatable?.should be_false

      UpdatableResource.creatable?.should be_false
      UpdatableResource.updatable?.should be_true

      Grapi::Resource.creatable?.should be_false
      Grapi::Resource.updatable?.should be_false
    end
  end
end

