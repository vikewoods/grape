require 'spec_helper'

describe Grape::Entity do
  let(:fresh_class) { Class.new(Grape::Entity) }

  context 'class methods' do
    subject { fresh_class }

    describe '.expose' do
      context 'multiple attributes' do
        it 'should be able to add multiple exposed attributes with a single call' do
          subject.expose :name, :email, :location
          subject.exposures.size.should == 3
        end

        it 'should set the same options for all exposures passed' do
          subject.expose :name, :email, :location, :foo => :bar
          subject.exposures.values.each{|v| v.should == {:foo => :bar}}
        end
      end

      context 'option validation' do
        it 'should make sure that :as only works on single attribute calls' do
          expect{ subject.expose :name, :email, :as => :foo }.to raise_error(ArgumentError)
          expect{ subject.expose :name, :as => :foo }.not_to raise_error
        end

        it 'should make sure that :format_with as a proc can not be used with a block' do
          expect { subject.expose :name, :format_with => Proc.new {} do |object,options| end }.to raise_error(ArgumentError)
        end
      end

      context 'with a block' do
        it 'should error out if called with multiple attributes' do
          expect{ subject.expose(:name, :email) do
            true
          end }.to raise_error(ArgumentError)
        end

        it 'should set the :proc option in the exposure options' do
          block = lambda{|obj,opts| true }
          subject.expose :name, &block
          subject.exposures[:name][:proc].should == block
        end
      end

      context 'inherited exposures' do
        it 'should return exposures from an ancestor' do
          subject.expose :name, :email
          child_class = Class.new(subject)

          child_class.exposures.should eq(subject.exposures)
        end

        it 'should return exposures from multiple ancestor' do
          subject.expose :name, :email
          parent_class = Class.new(subject)
          child_class  = Class.new(parent_class)

          child_class.exposures.should eq(subject.exposures)
        end

        it 'should return descendant exposures as a priotity' do
          subject.expose :name, :email
          child_class = Class.new(subject)
          child_class.expose :name do |n|
            'foo'
          end

          subject.exposures[:name].should_not have_key :proc
          child_class.exposures[:name].should have_key :proc
        end
      end

      context 'register formatters' do
        let(:date_formatter) { lambda {|date| date.strftime('%m/%d/%Y') }}

        it 'should register a formatter' do
          subject.format_with :timestamp, &date_formatter

          subject.formatters[:timestamp].should_not be_nil
        end

        it 'should inherit formatters from ancestors' do
          subject.format_with :timestamp, &date_formatter
          child_class = Class.new(subject)

          child_class.formatters.should == subject.formatters
        end

        it 'should not allow registering a formatter without a block' do
          expect{ subject.format_with :foo }.to raise_error(ArgumentError)
        end

        it 'should format an exposure with a registered formatter' do
          subject.format_with :timestamp do |date|
            date.strftime('%m/%d/%Y')
          end

          subject.expose :birthday, :format_with => :timestamp

          model  = { :birthday => Time.gm(2012, 2, 27) }
          subject.new(mock(model)).as_json[:birthday].should == '02/27/2012'
        end
      end
    end

    describe '.represent' do
      it 'should return a single entity if called with one object' do
        subject.represent(Object.new).should be_kind_of(subject)
      end

      it 'should return a single entity if called with a hash' do
        subject.represent(Hash.new).should be_kind_of(subject)
      end

      it 'should return multiple entities if called with a collection' do
        representation = subject.represent(4.times.map{Object.new})
        representation.should be_kind_of(Array)
        representation.size.should == 4
        representation.reject{|r| r.kind_of?(subject)}.should be_empty
      end

      it 'should add the :collection => true option if called with a collection' do
        representation = subject.represent(4.times.map{Object.new})
        representation.each{|r| r.options[:collection].should be_true}
      end
    end

    describe '.root' do
      context 'with singular and plural root keys' do
        before(:each) do
          subject.root 'things', 'thing'
        end

        context 'with a single object' do
          it 'should allow a root element name to be specified' do
            representation = subject.represent(Object.new)
            representation.should be_kind_of(Hash)
            representation.should have_key('thing')
            representation['thing'].should be_kind_of(subject)
          end
        end

        context 'with an array of objects' do
          it 'should allow a root element name to be specified' do
            representation = subject.represent(4.times.map{Object.new})
            representation.should be_kind_of(Hash)
            representation.should have_key('things')
            representation['things'].should be_kind_of(Array)
            representation['things'].size.should == 4
            representation['things'].reject{|r| r.kind_of?(subject)}.should be_empty
          end
        end

        context 'it can be overridden' do
          it 'can be disabled' do
            representation = subject.represent(4.times.map{Object.new}, :root=>false)
            representation.should be_kind_of(Array)
            representation.size.should == 4
            representation.reject{|r| r.kind_of?(subject)}.should be_empty
          end
          it 'can use a different name' do
            representation = subject.represent(4.times.map{Object.new}, :root=>'others')
            representation.should be_kind_of(Hash)
            representation.should have_key('others')
            representation['others'].should be_kind_of(Array)
            representation['others'].size.should == 4
            representation['others'].reject{|r| r.kind_of?(subject)}.should be_empty
          end
        end
      end

      context 'with singular root key' do
        before(:each) do
          subject.root nil, 'thing'
        end

        context 'with a single object' do
          it 'should allow a root element name to be specified' do
            representation = subject.represent(Object.new)
            representation.should be_kind_of(Hash)
            representation.should have_key('thing')
            representation['thing'].should be_kind_of(subject)
          end
        end

        context 'with an array of objects' do
          it 'should allow a root element name to be specified' do
            representation = subject.represent(4.times.map{Object.new})
            representation.should be_kind_of(Array)
            representation.size.should == 4
            representation.reject{|r| r.kind_of?(subject)}.should be_empty
          end
        end
      end

      context 'with plural root key' do
        before(:each) do
          subject.root 'things'
        end

        context 'with a single object' do
          it 'should allow a root element name to be specified' do
            subject.represent(Object.new).should be_kind_of(subject)
          end
        end

        context 'with an array of objects' do
          it 'should allow a root element name to be specified' do
            representation = subject.represent(4.times.map{Object.new})
            representation.should be_kind_of(Hash)
            representation.should have_key('things')
            representation['things'].should be_kind_of(Array)
            representation['things'].size.should == 4
            representation['things'].reject{|r| r.kind_of?(subject)}.should be_empty
          end
        end
      end
    end

    describe '#initialize' do
      it 'should take an object and an optional options hash' do
        expect{ subject.new(Object.new) }.not_to raise_error
        expect{ subject.new }.to raise_error(ArgumentError)
        expect{ subject.new(Object.new, {}) }.not_to raise_error
      end

      it 'should have attribute readers for the object and options' do
        entity = subject.new('abc', {})
        entity.object.should == 'abc'
        entity.options.should == {}
      end
    end
  end

  context 'instance methods' do
    
    let(:model){ mock(attributes) }
    
    let(:attributes) { {
      :name => 'Bob Bobson',
      :email => 'bob@example.com',
      :birthday => Time.gm(2012, 2, 27),
      :fantasies => ['Unicorns', 'Double Rainbows', 'Nessy'],
      :friends => [
        mock(:name => "Friend 1", :email => 'friend1@example.com', :fantasies => [], :birthday => Time.gm(2012, 2, 27), :friends => []),
        mock(:name => "Friend 2", :email => 'friend2@example.com', :fantasies => [], :birthday => Time.gm(2012, 2, 27), :friends => [])
      ]
    } }
    
    subject{ fresh_class.new(model) }

    describe '#serializable_hash' do

      it 'should not throw an exception if a nil options object is passed' do
        expect{ fresh_class.new(model).serializable_hash(nil) }.not_to raise_error
      end

      it 'should not blow up when the model is nil' do
        fresh_class.expose :name
        expect{ fresh_class.new(nil).serializable_hash }.not_to raise_error
      end

      it 'should not throw an exception when an attribute is not found on the object' do
        fresh_class.expose :name, :non_existant_attribute
        expect{ fresh_class.new(model).serializable_hash }.not_to raise_error
      end

      it "should not expose attributes that don't exist on the object" do
        fresh_class.expose :email, :non_existant_attribute, :name

        res = fresh_class.new(model).serializable_hash
        res.should have_key :email
        res.should_not have_key :non_existant_attribute
        res.should have_key :name
      end

      it "should not expose attributes that don't exist on the object, even with criteria" do
        fresh_class.expose :email
        fresh_class.expose :non_existant_attribute, :if => lambda { false }
        fresh_class.expose :non_existant_attribute2, :if => lambda { true }

        res = fresh_class.new(model).serializable_hash
        res.should have_key :email
        res.should_not have_key :non_existant_attribute
        res.should_not have_key :non_existant_attribute2
      end

      it "should expose attributes that don't exist on the object only when they are generated by a block" do
        fresh_class.expose :non_existant_attribute do |model, options|
          "well, I do exist after all"
        end
        res = fresh_class.new(model).serializable_hash
        res.should have_key :non_existant_attribute
      end

      it "should not expose attributes that are generated by a block but have not passed criteria" do
        fresh_class.expose :non_existant_attribute, :proc => lambda {|model, options|
          "I exist, but it is not yet my time to shine"
        }, :if => lambda { |model, options| false }
        res = fresh_class.new(model).serializable_hash
        res.should_not have_key :non_existant_attribute
      end
      
      context "#serializable_hash" do
      
        module EntitySpec
          class EmbeddedExample
            def serializable_hash(opts = {})
              { :abc => 'def' }
            end
          end
          class EmbeddedExampleWithMany
            def name
              "abc"
            end
            def embedded
              [ EmbeddedExample.new, EmbeddedExample.new ]
            end
          end
          class EmbeddedExampleWithOne
            def name
              "abc"
            end
            def embedded
              EmbeddedExample.new
            end
          end
        end
      
        it 'should serialize embedded objects which respond to #serializable_hash' do
          fresh_class.expose :name, :embedded
          presenter = fresh_class.new(EntitySpec::EmbeddedExampleWithOne.new)
          presenter.serializable_hash.should == {:name => "abc", :embedded => {:abc => "def"}}
        end

        it 'should serialize embedded arrays of objects which respond to #serializable_hash' do
          fresh_class.expose :name, :embedded
          presenter = fresh_class.new(EntitySpec::EmbeddedExampleWithMany.new)
          presenter.serializable_hash.should == {:name => "abc", :embedded => [{:abc => "def"}, {:abc => "def"}]}
        end
        
      end
      
    end

    describe '#value_for' do
      before do
        fresh_class.class_eval do
          expose :name, :email
          expose :friends, :using => self
          expose :computed do |object, options|
            options[:awesome]
          end

          expose :birthday, :format_with => :timestamp

          def timestamp(date)
            date.strftime('%m/%d/%Y')
          end

          expose :fantasies, :format_with => lambda {|f| f.reverse }
        end
      end

      it 'should pass through bare expose attributes' do
        subject.send(:value_for, :name).should == attributes[:name]
      end

      it 'should instantiate a representation if that is called for' do
        rep = subject.send(:value_for, :friends)
        rep.reject{|r| r.is_a?(fresh_class)}.should be_empty
        rep.first.serializable_hash[:name].should == 'Friend 1'
        rep.last.serializable_hash[:name].should == 'Friend 2'
      end

      it 'should disable root key name for child representations' do
      
        module EntitySpec
          class FriendEntity < Grape::Entity
            root 'friends', 'friend'
            expose :name, :email
          end
        end
        
        fresh_class.class_eval do
          expose :friends, :using => EntitySpec::FriendEntity
        end
        
        rep = subject.send(:value_for, :friends)
        rep.should be_kind_of(Array)
        rep.reject{|r| r.is_a?(EntitySpec::FriendEntity)}.should be_empty
        rep.first.serializable_hash[:name].should == 'Friend 1'
        rep.last.serializable_hash[:name].should == 'Friend 2'
      end

      it 'should call through to the proc if there is one' do
        subject.send(:value_for, :computed, :awesome => 123).should == 123
      end

      it 'should return a formatted value if format_with is passed' do
        subject.send(:value_for, :birthday).should == '02/27/2012'
      end

      it 'should return a formatted value if format_with is passed a lambda' do
        subject.send(:value_for, :fantasies).should == ['Nessy', 'Double Rainbows', 'Unicorns']
      end
    end

    describe '#documentation' do
      it 'should return an empty hash is no documentation is provided' do
        fresh_class.expose :name

        subject.documentation.should == {}
      end

      it 'should return each defined documentation hash' do
        doc = {:type => "foo", :desc => "bar"}
        fresh_class.expose :name, :documentation => doc
        fresh_class.expose :email, :documentation => doc
        fresh_class.expose :birthday

        subject.documentation.should == {:name  => doc, :email => doc}
      end
    end

    describe '#key_for' do
      it 'should return the attribute if no :as is set' do
        fresh_class.expose :name
        subject.send(:key_for, :name).should == :name
      end

      it 'should return a symbolized version of the attribute' do
        fresh_class.expose :name
        subject.send(:key_for, 'name').should == :name
      end

      it 'should return the :as alias if one exists' do
        fresh_class.expose :name, :as => :nombre
        subject.send(:key_for, 'name').should == :nombre
      end
    end

    describe '#conditions_met?' do
      it 'should only pass through hash :if exposure if all attributes match' do
        exposure_options = {:if => {:condition1 => true, :condition2 => true}}

        subject.send(:conditions_met?, exposure_options, {}).should be_false
        subject.send(:conditions_met?, exposure_options, :condition1 => true).should be_false
        subject.send(:conditions_met?, exposure_options, :condition1 => true, :condition2 => true).should be_true
        subject.send(:conditions_met?, exposure_options, :condition1 => false, :condition2 => true).should be_false
        subject.send(:conditions_met?, exposure_options, :condition1 => true, :condition2 => true, :other => true).should be_true
      end

      it 'should only pass through proc :if exposure if it returns truthy value' do
        exposure_options = {:if => lambda{|obj,opts| opts[:true]}}

        subject.send(:conditions_met?, exposure_options, :true => false).should be_false
        subject.send(:conditions_met?, exposure_options, :true => true).should be_true
      end

      it 'should only pass through hash :unless exposure if any attributes do not match' do
        exposure_options = {:unless => {:condition1 => true, :condition2 => true}}

        subject.send(:conditions_met?, exposure_options, {}).should be_true
        subject.send(:conditions_met?, exposure_options, :condition1 => true).should be_false
        subject.send(:conditions_met?, exposure_options, :condition1 => true, :condition2 => true).should be_false
        subject.send(:conditions_met?, exposure_options, :condition1 => false, :condition2 => true).should be_false
        subject.send(:conditions_met?, exposure_options, :condition1 => true, :condition2 => true, :other => true).should be_false
        subject.send(:conditions_met?, exposure_options, :condition1 => false, :condition2 => false).should be_true
      end

      it 'should only pass through proc :unless exposure if it returns falsy value' do
        exposure_options = {:unless => lambda{|object,options| options[:true] == true}}

        subject.send(:conditions_met?, exposure_options, :true => false).should be_true
        subject.send(:conditions_met?, exposure_options, :true => true).should be_false
      end
    end

    describe "::DSL" do
      subject{ Class.new }

      it 'should create an Entity class when called' do
        subject.should_not be_const_defined(:Entity)
        subject.send(:include, Grape::Entity::DSL)
        subject.should be_const_defined(:Entity)
      end

      context 'pre-mixed' do
        before{ subject.send(:include, Grape::Entity::DSL) }

        it 'should be able to define entity traits through DSL' do
          subject.entity do
            expose :name
          end

          subject.entity_class.exposures.should_not be_empty
        end

        it 'should be able to expose straight from the class' do
          subject.entity :name, :email
          subject.entity_class.exposures.size.should == 2
        end

        it 'should be able to mix field and advanced exposures' do
          subject.entity :name, :email do
            expose :third
          end
          subject.entity_class.exposures.size.should == 3
        end

        context 'instance' do
          let(:instance){ subject.new }

          describe '#entity' do
            it 'should be an instance of the entity class' do
              instance.entity.should be_kind_of(subject.entity_class)
            end

            it 'should have an object of itself' do
              instance.entity.object.should == instance
            end
          end
        end
      end
    end
  end
end
