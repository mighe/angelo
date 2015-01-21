require_relative '../spec_helper'
require 'openssl'

describe Angelo::Server do

  describe 'serving static files from many public folders' do

    define_app do

      @root = TEST_APP_ROOT

      public_dir ['public', 'public_2']

    end

    it 'serves static files that exist only in the first folder' do
      get '/test.js'

      last_response.status.must_equal 200
      last_response.body.to_s.must_equal File.read(File.join TEST_APP_ROOT, 'public', 'test.js')
    end

    it 'serves static files that exist only in the second folder' do
      get '/a_file.html'

      last_response.status.must_equal 200
      last_response.body.to_s.must_equal File.read(File.join TEST_APP_ROOT, 'public_2', 'a_file.html')
    end

    it 'serves the file from the first folder when many have' do
      get '/test.html'

      last_response.status.must_equal 200
      last_response.body.to_s.must_equal File.read(File.join TEST_APP_ROOT, 'public', 'test.html')
    end

    it '404s when send_file is called with a non-existent file' do
      get '/does_not_exist'
      last_response.status.must_equal 404
    end

  end
end
