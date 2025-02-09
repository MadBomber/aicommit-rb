# frozen_string_literal: true

require "test_helper"
require 'fileutils'
require 'time'

class TestAigcm < Minitest::Test
  def setup
    @test_message = 'feat: example commit message'
    @orig_dir = Dir.pwd
    @temp_dir = Dir.mktmpdir
    Dir.chdir(@temp_dir)
    system('git init')
    File.write('test.txt', 'This is a test file to ensure changes are detected.')
    system('git add test.txt')
    stub_ai_client
  end

  def teardown
    Dir.chdir(@orig_dir)
    FileUtils.remove_entry @temp_dir if @temp_dir && Dir.exist?(@temp_dir)
  end

  def stub_ai_client
    mock_client = Object.new

    def mock_client.chat(_)
      'Simulated commit message'
    end

    def mock_client.provider
      :ollama
    end

    AiClient.stub :new, mock_client do
      yield if block_given?
    end
  end

  def test_that_it_has_a_version_number
    refute_nil ::Aigcm::VERSION
  end

  def test_run_with_invalid_provider
    ARGV.replace(['--provider=invalid'])
    assert_output(/Invalid provider specified/) do
      assert_raises(SystemExit) { Aigcm.run(test_mode: true) }
    end
  end

  def test_run_dry_mode
    ARGV.replace(['--dry'])

    stub_ai_client do
      output = capture_io { Aigcm.run(test_mode: true) }[0]
      assert_match(/Dry run - would generate commit message:/, output)
      assert_equal true, File.exist?(File.join(@temp_dir, '.aigcm_msg'))
      assert_equal 'Simulated commit message', File.read(File.join(@temp_dir, '.aigcm_msg'))
    end
  end

  def test_run_with_recent_message
    commit_msg_path = File.join(@temp_dir, '.aigcm_msg')
    File.write(commit_msg_path, @test_message)
    File.utime(Time.now, Time.now, commit_msg_path)

    ARGV.replace([])

    stub_ai_client do
      Aigcm.run(test_mode: true)
      # Check if it reads the recent message
      assert File.exist?(commit_msg_path)
      assert_equal @test_message, File.read(commit_msg_path)
    end
  end

  def test_run_with_old_message
    commit_msg_path = File.join(@temp_dir, '.aigcm_msg')
    File.write(commit_msg_path, @test_message)
    File.utime(Time.now - 3600, Time.now - 3600, commit_msg_path)

    ARGV.replace([])

    stub_ai_client do
      Aigcm.run(test_mode: true)
      # Check if it generates a new commit message
      assert File.exist?(commit_msg_path)
      assert_equal 'Simulated commit message', File.read(commit_msg_path)
    end
  end

  def test_run_with_commit_message_written
    ARGV.replace([])

    stub_ai_client do
      Aigcm.run(test_mode: true)
      commit_msg_path = File.join(@temp_dir, '.aigcm_msg')
      assert File.exist?(commit_msg_path)
      assert_equal 'Simulated commit message', File.read(commit_msg_path)
    end
  end
end
