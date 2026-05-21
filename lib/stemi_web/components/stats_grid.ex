defmodule StemiWeb.Components.StatsGrid do
  @moduledoc "Reusable stats grid component for all role views."
  use Phoenix.Component

  def stats_grid(assigns) do
    ~H"""
    <div style="display: grid; grid-template-columns: repeat(3, 1fr); gap: 8px; margin-bottom: 12px;">
      <div style="background: var(--bg-secondary); border-radius: 10px; padding: 10px; text-align: center; border: 1px solid var(--border);">
        <div style="font-size: 22px; font-weight: 800; color: #f59e0b;">{@stats.pending}</div>
        <div style="font-size: 11px; color: var(--text-muted); margin-top: 4px;">Pending</div>
      </div>
      <div style="background: var(--bg-secondary); border-radius: 10px; padding: 10px; text-align: center; border: 1px solid var(--border);">
        <div style="font-size: 22px; font-weight: 800; color: #a855f7;">{@stats.er_approved}</div>
        <div style="font-size: 11px; color: var(--text-muted); margin-top: 4px;">ER Approved</div>
      </div>
      <div style="background: var(--bg-secondary); border-radius: 10px; padding: 10px; text-align: center; border: 1px solid var(--border);">
        <div style="font-size: 22px; font-weight: 800; color: #22c55e;">{@stats.approved}</div>
        <div style="font-size: 11px; color: var(--text-muted); margin-top: 4px;">Approved</div>
      </div>
      <div style="background: var(--bg-secondary); border-radius: 10px; padding: 10px; text-align: center; border: 1px solid var(--border);">
        <div style="font-size: 22px; font-weight: 800; color: #3b82f6;">{@stats.dispatched}</div>
        <div style="font-size: 11px; color: var(--text-muted); margin-top: 4px;">Dispatched</div>
      </div>
      <div style="background: var(--bg-secondary); border-radius: 10px; padding: 10px; text-align: center; border: 1px solid var(--border);">
        <div style="font-size: 22px; font-weight: 800; color: #ef4444;">{@stats.rejected}</div>
        <div style="font-size: 11px; color: var(--text-muted); margin-top: 4px;">Rejected</div>
      </div>
      <div style="background: var(--bg-secondary); border-radius: 10px; padding: 10px; text-align: center; border: 1px solid var(--border);">
        <div style="font-size: 22px; font-weight: 800; color: #10b981;">{@stats.total}</div>
        <div style="font-size: 11px; color: var(--text-muted); margin-top: 4px;">Total</div>
      </div>
    </div>
    """
  end
end
