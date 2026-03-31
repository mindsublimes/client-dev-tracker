# frozen_string_literal: true

class IssueInvoiceFromMilestoneJob < ApplicationJob
  queue_as :default

  def perform(agenda_item_id)
    Financial::MilestoneInvoiceCreator.call(agenda_item_id)
  end
end
