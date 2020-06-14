require "test_helper"

module ActionClient
  class HttpStatusFilterTest < ActiveSupport::TestCase
    test "#include? returns true when the status is nil" do
      filter = HttpStatusFilter.new(nil)
      status_codes = 100..599

      included = status_codes.all? { |status_code| filter.include?(status_code) }

      assert_equal true, included
    end

    test "#include? delegates to a Range" do
      filter = HttpStatusFilter.new(100..599)

      included = filter.include?(101)
      excluded = filter.include?(600)

      assert_equal true, included
      assert_equal false, excluded
    end

    test "#include? delegates to an Endless Range" do
      filter = HttpStatusFilter.new(100..)

      included = filter.include?(101)
      excluded = filter.include?(99)

      assert_equal true, included
      assert_equal false, excluded
    end

    test "#include? covers an Array of status codes" do
      filter = HttpStatusFilter.new([401, 403])

      included = filter.include?(401)
      excluded = filter.include?(422)

      assert_equal true, included
      assert_equal false, excluded
    end

    test "#include? covers an Array of status names" do
      filter = HttpStatusFilter.new([:unauthorized, :forbidden])

      included = filter.include?(401)
      excluded = filter.include?(422)

      assert_equal true, included
      assert_equal false, excluded
    end

    test "#include? covers an Array of mixed statuses" do
      filter = HttpStatusFilter.new([401, :forbidden])

      included = filter.include?(401)
      excluded = filter.include?(422)

      assert_equal true, included
      assert_equal false, excluded
    end

    test "#include? covers a single item status name" do
      filter = HttpStatusFilter.new(:unauthorized)

      included = filter.include?(401)
      excluded = filter.include?(422)

      assert_equal true, included
      assert_equal false, excluded
    end

    test "#include? covers a single item status code" do
      filter = HttpStatusFilter.new(401)

      included = filter.include?(401)
      excluded = filter.include?(422)

      assert_equal true, included
      assert_equal false, excluded
    end

    test "#include? matches two status names" do
      filter = HttpStatusFilter.new(:unauthorized)

      included = filter.include?(:unauthorized)
      excluded = filter.include?(:unprocessable_entity)

      assert_equal true, included
      assert_equal false, excluded
    end

    test "#include? transforms the argument into a status code" do
      filter = HttpStatusFilter.new(401)

      included = filter.include?(:unauthorized)
      excluded = filter.include?(:unprocessable_entity)

      assert_equal true, included
      assert_equal false, excluded
    end
  end
end
