# frozen_string_literal: true

class InvoicesController < ApplicationController
  before_action :set_invoice, only: %i[show mark_paid]

  def index
    authorize Invoice
    @invoices = policy_scope(Invoice).includes(:client, agenda_item: :project).order(issued_at: :desc).limit(100)
  end

  def show
    authorize @invoice
  end

  def mark_paid
    authorize @invoice, :mark_paid?
    @invoice.update!(status: :paid, paid_at: Time.current)
    if @invoice.agenda_item.present? && !@invoice.agenda_item.paid?
      @invoice.agenda_item.update_columns(paid: true) # rubocop:disable Rails/SkipsModelValidations
    end
    redirect_to @invoice, success: 'Invoice marked as paid.'
  end

  private

  def set_invoice
    @invoice = policy_scope(Invoice).find(params[:id])
  end
end
