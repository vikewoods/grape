require 'spec_helper'

describe Grape::Validations::PresenceValidator do

  module ValidationsSpec
    module PresenceValidatorSpec
      class API < Grape::API
        default_format :json

        resource :bacons do
          get do
            "All the bacon"
          end
        end

        params do
          requires :id, :regexp => /^[0-9]+$/
        end
        post do
          {:ret => params[:id]}
        end
        
        params do
          requires :name, :company
        end
        get do
          "Hello"
        end

        params do
          group :user do
            requires :first_name, :last_name
          end
        end
        get '/nested' do
          "Nested"
        end

        params do
          group :admin do
            requires :admin_name
            group :super do
              group :user do
                requires :first_name, :last_name
              end
            end
          end
        end
        get '/nested_triple' do
          "Nested triple"
        end
      end
    end
  end
  
  def app
    ValidationsSpec::PresenceValidatorSpec::API
  end

  it "does not validate for any params" do
    get("/bacons")
    last_response.status.should == 200
    last_response.body.should == "All the bacon"
  end
  
  it 'validates id' do
    post('/')
    last_response.status.should == 400
    last_response.body.should == "missing parameter: id"
    
    post('/', {}, 'rack.input' => StringIO.new('{"id" : "a56b"}'))
    last_response.body.should == 'invalid parameter: id'
    last_response.status.should == 400
    
    post('/', {}, 'rack.input' => StringIO.new('{"id" : 56}'))
    last_response.body.should == '{"ret":56}'
    last_response.status.should == 201
  end
  
  it 'validates name, company' do
    get('/')
    last_response.status.should == 400
    last_response.body.should == "missing parameter: name"
    
    get('/', :name => "Bob")
    last_response.status.should == 400
    last_response.body.should == "missing parameter: company"
    
    get('/', :name => "Bob", :company => "TestCorp")
    last_response.status.should == 200
    last_response.body.should == "Hello"
  end

  it 'validates nested parameters' do
    get('/nested')
    last_response.status.should == 400
    last_response.body.should == "missing parameter: first_name"

    get('/nested', :user => {:first_name => "Billy"})
    last_response.status.should == 400
    last_response.body.should == "missing parameter: last_name"

    get('/nested', :user => {:first_name => "Billy", :last_name => "Bob"})
    last_response.status.should == 200
    last_response.body.should == "Nested"
  end

  it 'validates triple nested parameters' do
    get('/nested_triple')
    last_response.status.should == 400
    last_response.body.should == "missing parameter: admin_name"

    get('/nested_triple', :user => {:first_name => "Billy"})
    last_response.status.should == 400
    last_response.body.should == "missing parameter: admin_name"

    get('/nested_triple', :admin => {:super => {:first_name => "Billy"}})
    last_response.status.should == 400
    last_response.body.should == "missing parameter: admin_name"

    get('/nested_triple', :super => {:user => {:first_name => "Billy", :last_name => "Bob"}})
    last_response.status.should == 400
    last_response.body.should == "missing parameter: admin_name"

    get('/nested_triple', :admin => {:super => {:user => {:first_name => "Billy"}}})
    last_response.status.should == 400
    last_response.body.should == "missing parameter: admin_name"

    get('/nested_triple', :admin => { :admin_name => 'admin', :super => {:user => {:first_name => "Billy"}}})
    last_response.status.should == 400
    last_response.body.should == "missing parameter: last_name"

    get('/nested_triple', :admin => { :admin_name => 'admin', :super => {:user => {:first_name => "Billy", :last_name => "Bob"}}})
    last_response.status.should == 200
    last_response.body.should == "Nested triple"
  end

end
