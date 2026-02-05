# frozen_string_literal: true

namespace :bot do
  desc "Run all bot tests"
  task test: :environment do
    puts "🤖 Running all bot tests..."
    puts "=" * 60

    # Run system tests tagged as bot tests
    system("bin/rails test test/system/")

    puts "=" * 60
    puts "🤖 Bot tests complete!"
  end

  namespace :test do
    desc "Run trading bot tests"
    task trading: :environment do
      puts "🤖 Running trading bot tests..."
      puts "=" * 60

      test_file = Rails.root.join("test/system/bot_trading_test.rb")
      if File.exist?(test_file)
        system("bin/rails test #{test_file}")
      else
        puts "⚠️  No trading tests found at #{test_file}"
        puts "   Run 'rails generate system_test bot_trading' to create one."
      end

      puts "=" * 60
      puts "🤖 Trading tests complete!"
    end

    desc "Run onboarding bot tests"
    task onboarding: :environment do
      puts "🤖 Running onboarding bot tests..."
      puts "=" * 60

      test_file = Rails.root.join("test/system/bot_onboarding_test.rb")
      if File.exist?(test_file)
        system("bin/rails test #{test_file}")
      else
        puts "⚠️  No onboarding tests found at #{test_file}"
        puts "   Run 'rails generate system_test bot_onboarding' to create one."
      end

      puts "=" * 60
      puts "🤖 Onboarding tests complete!"
    end

    desc "Run smoke tests (P0 critical path only)"
    task smoke: :environment do
      puts "🤖 Running P0 smoke tests..."
      puts "=" * 60

      # Run only tests tagged with metadata: { smoke: true }
      # For now, run the critical system tests
      test_files = [
        "test/system/bot_onboarding_test.rb",
        "test/system/bot_trading_test.rb"
      ].map { |f| Rails.root.join(f) }.select { |f| File.exist?(f) }

      if test_files.any?
        system("bin/rails test #{test_files.join(' ')}")
      else
        puts "⚠️  No smoke tests found."
        puts "   Create bot test files in test/system/ first."
      end

      puts "=" * 60
      puts "🤖 Smoke tests complete!"
    end

    desc "Run navigation/exploration bot tests"
    task navigation: :environment do
      puts "🤖 Running navigation bot tests..."
      puts "=" * 60

      test_file = Rails.root.join("test/system/bot_navigation_test.rb")
      if File.exist?(test_file)
        system("bin/rails test #{test_file}")
      else
        puts "⚠️  No navigation tests found at #{test_file}"
      end

      puts "=" * 60
      puts "🤖 Navigation tests complete!"
    end

    desc "Run worker/NPC management bot tests"
    task workers: :environment do
      puts "🤖 Running worker management bot tests..."
      puts "=" * 60

      test_file = Rails.root.join("test/system/bot_workers_test.rb")
      if File.exist?(test_file)
        system("bin/rails test #{test_file}")
      else
        puts "⚠️  No worker tests found at #{test_file}"
      end

      puts "=" * 60
      puts "🤖 Worker tests complete!"
    end
  end

  desc "List available bot test tasks"
  task list: :environment do
    puts "🤖 Available Bot Test Tasks:"
    puts "=" * 60
    puts "  rails bot:test              - Run all bot tests"
    puts "  rails bot:test:trading      - Run trading loop tests"
    puts "  rails bot:test:onboarding   - Run onboarding flow tests"
    puts "  rails bot:test:smoke        - Run P0 critical tests only"
    puts "  rails bot:test:navigation   - Run navigation tests"
    puts "  rails bot:test:workers      - Run worker management tests"
    puts "=" * 60
    puts ""
    puts "Test files should be created in test/system/ directory."
    puts "See docs/BOT_TEST_MATRIX.md for test case definitions."
  end
end
