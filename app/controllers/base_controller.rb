require 'spree/core/controller_helpers/respond_with_decorator'
require 'open_food_network/tag_rule_applicator'

class BaseController < ApplicationController
  include Spree::Core::ControllerHelpers
  include Spree::Core::ControllerHelpers::Auth
  include Spree::Core::ControllerHelpers::Common
  include Spree::Core::ControllerHelpers::Order
  include Spree::Core::ControllerHelpers::RespondWith

  include I18nHelper
  include EnterprisesHelper
  include OrderCyclesHelper

  helper 'spree/base'

  # Spree::Core::ControllerHelpers declares helper_method get_taxonomies, so we need to
  # include Spree::ProductsHelper so that method is available on the controller
  include Spree::ProductsHelper

  before_filter :set_locale
  before_filter :check_order_cycle_expiry

  private

  def set_order_cycles
    unless @distributor.ready_for_checkout?
      @order_cycles = OrderCycle.where('false')
      return
    end

    @order_cycles = OrderCycle.with_distributor(@distributor).active
      .order(@distributor.preferred_shopfront_order_cycle_order)

    applicator = OpenFoodNetwork::TagRuleApplicator.new(@distributor,
                                                        "FilterOrderCycles",
                                                        current_customer.andand.tag_list)
    applicator.filter!(@order_cycles)

    reset_order_cycle
  end

  # Default to the only order cycle if there's only one
  #
  # Here we need to use @order_cycles.size not @order_cycles.count
  #   because TagRuleApplicator changes ActiveRecord::Relation @order_cycles
  #     and these changes are not seen if the relation is reloaded with count
  def reset_order_cycle
    return if @order_cycles.size != 1

    current_order(true).set_order_cycle! @order_cycles.first
  end
end
