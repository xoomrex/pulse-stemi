defmodule StemiWeb.Components.CaseComments do
  @moduledoc """
  Threaded comments for a single case.

  Owned by a parent LiveView which is responsible for:
    1. Calling `Stemi.Cases.subscribe_comments(case_id)` while this component is visible.
    2. Re-sending `comments_tree` via `send_update/2` when a `:comment_added` message arrives.

  All authorization stays on the server — the parent passes `current_user`
  and we only accept new comments under that user's identity.
  """
  use StemiWeb, :live_component

  alias Stemi.Cases

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:reply_to, nil)
     |> assign(:draft, "")}
  end

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:comments_tree, fn -> Cases.list_comments_tree(assigns.case_id) end)}
  end

  @impl true
  def handle_event("reply", %{"id" => id}, socket) do
    {:noreply, assign(socket, reply_to: id, draft: "")}
  end

  @impl true
  def handle_event("cancel_reply", _params, socket) do
    {:noreply, assign(socket, reply_to: nil, draft: "")}
  end

  @impl true
  def handle_event("change_draft", %{"body" => body}, socket) do
    {:noreply, assign(socket, draft: body)}
  end

  @impl true
  def handle_event("submit", %{"body" => body, "parent_id" => parent_id}, socket) do
    body = String.trim(body || "")

    cond do
      body == "" ->
        {:noreply, socket}

      socket.assigns.current_user == nil ->
        {:noreply, socket}

      true ->
        parent =
          case parent_id do
            "" -> nil
            nil -> nil
            id -> id
          end

        case Cases.create_comment(%{
               case_id: socket.assigns.case_id,
               user_id: socket.assigns.current_user.id,
               parent_id: parent,
               body: body
             }) do
          {:ok, _} ->
            # PubSub will fire and the parent will re-send comments_tree.
            {:noreply, assign(socket, reply_to: nil, draft: "")}

          {:error, _} ->
            {:noreply, socket}
        end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="case-comments" id={@id}>
      <div class="case-comments__header">
        <span class="case-comments__title">Discussion</span>
        <span class="case-comments__count">{length(flatten_tree(@comments_tree))}</span>
        <span class="live-dot case-comments__live" title="Real-time thread">Live</span>
      </div>

      <div class="case-comments__tree">
        <%= for {comment, replies} <- @comments_tree do %>
          {render_node(assigns, comment, replies, 0)}
        <% end %>

        <div :if={@comments_tree == []} class="case-comments__empty">
          No notes yet — start the conversation below.
        </div>
      </div>

      <!-- Root reply form -->
      <form
        :if={@reply_to == nil}
        class="case-comments__form"
        phx-submit="submit"
        phx-target={@myself}
      >
        <input type="hidden" name="parent_id" value="" />
        <textarea
          class="form-input form-textarea case-comments__textarea"
          name="body"
          rows="2"
          placeholder="Add a note to the team…"
          phx-change="change_draft"
          phx-target={@myself}
        ></textarea>
        <button type="submit" class="btn btn--primary btn--sm">Send</button>
      </form>
    </div>
    """
  end

  defp render_node(assigns, comment, replies, depth) do
    assigns = assign(assigns, comment: comment, replies: replies, depth: depth)

    ~H"""
    <div class={"case-comments__node depth-#{min(@depth, 4)}"}>
      <div class="case-comments__bubble">
        <div class="case-comments__bubble-head">
          <span class="case-comments__author">
            {if @comment.user, do: @comment.user.full_name, else: "Someone"}
          </span>
          <span class="case-comments__role" :if={@comment.user && @comment.user.role}>
            {@comment.user.role}
          </span>
          <span class="case-comments__time">{relative_time(@comment.inserted_at)}</span>
        </div>
        <div class="case-comments__body">{@comment.body}</div>
        <button
          type="button"
          class="case-comments__reply-btn"
          phx-click="reply"
          phx-value-id={@comment.id}
          phx-target={@myself}
        >
          Reply
        </button>
      </div>

      <form
        :if={@reply_to == @comment.id}
        class="case-comments__form case-comments__form--reply"
        phx-submit="submit"
        phx-target={@myself}
      >
        <input type="hidden" name="parent_id" value={@comment.id} />
        <textarea
          class="form-input form-textarea case-comments__textarea"
          name="body"
          rows="2"
          placeholder={"Reply to #{if @comment.user, do: @comment.user.full_name, else: "this note"}…"}
          phx-target={@myself}
        ></textarea>
        <div class="case-comments__form-actions">
          <button type="button" class="btn btn--ghost btn--sm" phx-click="cancel_reply" phx-target={@myself}>Cancel</button>
          <button type="submit" class="btn btn--primary btn--sm">Reply</button>
        </div>
      </form>

      <div :if={@replies != []} class="case-comments__children">
        <%= for {child, grandchildren} <- @replies do %>
          {render_node(assigns, child, grandchildren, @depth + 1)}
        <% end %>
      </div>
    </div>
    """
  end

  defp flatten_tree(tree) do
    Enum.flat_map(tree, fn {c, replies} -> [c | flatten_tree(replies)] end)
  end

  defp relative_time(nil), do: ""

  defp relative_time(%DateTime{} = dt) do
    diff = DateTime.diff(DateTime.utc_now(), dt, :minute)

    cond do
      diff < 1 -> "Just now"
      diff < 60 -> "#{diff}m"
      diff < 1440 -> "#{div(diff, 60)}h"
      true -> "#{div(diff, 1440)}d"
    end
  end
end
