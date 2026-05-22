defmodule Stemi.Cases do
  @moduledoc """
  The Cases context — STEMI case lifecycle management.

  Flow: PHC → ER Consultant → Cardiologist → (parallel) EMS + Cath Lab + Eligibility

  All mutations broadcast on PubSub topic "cases" for real-time updates.
  """
  import Ecto.Query
  alias Stemi.Repo
  alias Stemi.Cases.{Case, CaseComment}

  @topic "cases"

  # --- PubSub ---

  def subscribe do
    Phoenix.PubSub.subscribe(Stemi.PubSub, @topic)
  end

  def subscribe_comments(case_id) do
    Phoenix.PubSub.subscribe(Stemi.PubSub, comments_topic(case_id))
  end

  def unsubscribe_comments(case_id) do
    Phoenix.PubSub.unsubscribe(Stemi.PubSub, comments_topic(case_id))
  end

  defp comments_topic(case_id), do: "case_comments:#{case_id}"

  defp broadcast({:ok, result}, event) do
    Phoenix.PubSub.broadcast(Stemi.PubSub, @topic, {event, result})
    {:ok, result}
  end

  defp broadcast({:error, _} = error, _event), do: error

  defp broadcast_comment({:ok, %CaseComment{} = c}, event) do
    c = Repo.preload(c, :user)
    Phoenix.PubSub.broadcast(Stemi.PubSub, comments_topic(c.case_id), {event, c})
    # Also nudge the cases topic so list views can refresh counts/badges.
    Phoenix.PubSub.broadcast(Stemi.PubSub, @topic, {:case_comment_added, c})
    {:ok, c}
  end

  defp broadcast_comment({:error, _} = error, _event), do: error

  # --- Stats (used by all role views for dashboard cards) ---

  def case_stats do
    counts =
      from(c in Case,
        where: c.is_deleted == false,
        group_by: c.status,
        select: {c.status, count(c.id)}
      )
      |> Repo.all()
      |> Map.new()

    total = counts |> Map.values() |> Enum.sum()

    %{
      pending: Map.get(counts, "pending_review", 0) + Map.get(counts, "pending_er", 0),
      er_approved: Map.get(counts, "er_approved", 0),
      approved: Map.get(counts, "approved", 0),
      dispatched: Map.get(counts, "dispatched", 0),
      rejected: Map.get(counts, "rejected", 0) + Map.get(counts, "er_rejected", 0),
      total: total
    }
  end

  # --- Queries ---

  def list_cases_for_phc(user_id) do
    Case
    |> where([c], c.phc_user_id == ^user_id and c.is_deleted == false)
    |> order_by([c], desc: c.inserted_at)
    |> Repo.all()
  end

  # ER Consultant sees all non-deleted cases (pending_er first)
  def list_er_cases do
    Case
    |> where([c], c.is_deleted == false)
    |> order_by([c], [asc: fragment("CASE WHEN status = 'pending_er' OR status = 'pending_review' THEN 0 ELSE 1 END"), asc: :inserted_at])
    |> preload([:phc_user, :phc_hospital])
    |> Repo.all()
  end

  # Cardiologist sees cases forwarded by ER (er_approved)
  def list_cardio_cases do
    Case
    |> where([c], c.er_decision == "approved" and c.is_deleted == false)
    |> order_by([c], [asc: fragment("CASE WHEN cardiology_decision IS NULL THEN 0 ELSE 1 END"), asc: :inserted_at])
    |> preload([:phc_user, :phc_hospital, :er_consultant])
    |> Repo.all()
  end

  # Eligibility: sees cases after Cardio approval (parallel phase)
  def list_approved_cases do
    Case
    |> where([c], c.cardiology_decision == "approved" and c.is_deleted == false)
    |> order_by([c], [asc: fragment("CASE WHEN mrn_number IS NULL OR mrn_number = '' THEN 0 ELSE 1 END"), asc: :inserted_at])
    |> preload([:phc_user, :phc_hospital, :er_consultant, :cardiologist])
    |> Repo.all()
  end

  # EMS: sees cases after Cardio approval (parallel phase - no longer waits for MRN)
  def list_ready_for_dispatch do
    Case
    |> where([c], c.cardiology_decision == "approved" and c.is_deleted == false)
    |> order_by([c], [asc: fragment("CASE WHEN status = 'dispatched' OR status = 'completed' THEN 1 ELSE 0 END"), asc: :inserted_at])
    |> preload([:phc_user, :phc_hospital, :er_consultant, :cardiologist, :eligibility])
    |> Repo.all()
  end

  # Cath Lab: sees cases after Cardio approval (parallel phase)
  def list_cath_lab_cases do
    Case
    |> where([c], c.cardiology_decision == "approved" and c.is_deleted == false)
    |> order_by([c], [asc: fragment("CASE WHEN cath_lab_status = 'pending' THEN 0 WHEN cath_lab_status = 'preparing' THEN 1 ELSE 2 END"), asc: :inserted_at])
    |> preload([:phc_user, :phc_hospital, :er_consultant, :cardiologist, :eligibility, :ems_user])
    |> Repo.all()
  end

  # Lightweight variants for list/card rendering — only preload what cards display.
  # get_case!/1 still loads full preloads for the detail panel.

  def list_er_cases_for_list do
    Case
    |> where([c], c.is_deleted == false)
    |> order_by([c], [asc: fragment("CASE WHEN status = 'pending_er' OR status = 'pending_review' THEN 0 ELSE 1 END"), asc: :inserted_at])
    |> preload([:phc_user, :phc_hospital])
    |> Repo.all()
  end

  def list_cardio_cases_for_list do
    Case
    |> where([c], c.er_decision == "approved" and c.is_deleted == false)
    |> order_by([c], [asc: fragment("CASE WHEN cardiology_decision IS NULL THEN 0 ELSE 1 END"), asc: :inserted_at])
    |> preload([:phc_user, :phc_hospital])
    |> Repo.all()
  end

  def list_approved_cases_for_list do
    Case
    |> where([c], c.cardiology_decision == "approved" and c.is_deleted == false)
    |> order_by([c], [asc: fragment("CASE WHEN mrn_number IS NULL OR mrn_number = '' THEN 0 ELSE 1 END"), asc: :inserted_at])
    |> preload([:phc_user, :phc_hospital])
    |> Repo.all()
  end

  def list_ready_for_dispatch_for_list do
    Case
    |> where([c], c.cardiology_decision == "approved" and c.is_deleted == false)
    |> order_by([c], [asc: fragment("CASE WHEN status = 'dispatched' OR status = 'completed' THEN 1 ELSE 0 END"), asc: :inserted_at])
    |> preload([:phc_user, :phc_hospital])
    |> Repo.all()
  end

  def list_cath_lab_cases_for_list do
    Case
    |> where([c], c.cardiology_decision == "approved" and c.is_deleted == false)
    |> order_by([c], [asc: fragment("CASE WHEN cath_lab_status = 'pending' THEN 0 WHEN cath_lab_status = 'preparing' THEN 1 ELSE 2 END"), asc: :inserted_at])
    |> preload([:phc_user, :phc_hospital])
    |> Repo.all()
  end

  # Legacy: pending only
  def list_pending_cases do
    Case
    |> where([c], c.status in ["pending_review", "pending_er"] and c.is_deleted == false)
    |> order_by([c], asc: c.inserted_at)
    |> preload([:phc_user, :phc_hospital])
    |> Repo.all()
  end

  # Admin / Universal tracking: see ALL cases
  def list_all_cases do
    Case
    |> order_by([c], desc: c.inserted_at)
    |> preload([:phc_user, :phc_hospital, :er_consultant, :cardiologist, :eligibility, :ems_user, :cath_lab_user])
    |> Repo.all()
  end

  def list_all_active_cases do
    Case
    |> where([c], c.is_deleted == false)
    |> order_by([c], desc: c.inserted_at)
    |> preload([:phc_user, :phc_hospital, :er_consultant, :cardiologist, :eligibility, :ems_user, :cath_lab_user])
    |> Repo.all()
  end

  def get_case!(id) do
    Case
    |> Repo.get!(id)
    |> Repo.preload([:phc_user, :phc_hospital, :er_consultant, :cardiologist, :eligibility, :ems_user, :cath_lab_user])
  end

  # --- Mutations (all broadcast) ---

  def create_case(attrs) do
    changeset = Case.create_changeset(%Case{}, attrs)
    initial_comment = Ecto.Changeset.get_change(changeset, :initial_comment)

    Repo.transaction(fn ->
      case Repo.insert(changeset) do
        {:ok, case_record} ->
          if is_binary(initial_comment) and String.trim(initial_comment) != "" do
            %CaseComment{}
            |> CaseComment.changeset(%{
              case_id: case_record.id,
              user_id: Ecto.Changeset.get_change(changeset, :phc_user_id),
              body: initial_comment,
              parent_id: nil
            })
            |> Repo.insert!()
          end

          case_record

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
    |> case do
      {:ok, case_record} -> broadcast({:ok, case_record}, :case_created)
      {:error, _} = err -> err
    end
  end

  # --- Comments ---

  def list_comments(case_id) do
    CaseComment
    |> where([c], c.case_id == ^case_id and c.is_deleted == false)
    |> order_by([c], asc: c.inserted_at)
    |> preload(:user)
    |> Repo.all()
  end

  @doc """
  Returns comments shaped as a tree: `[{comment, [{reply, [...]}]}, ...]`.
  Builds in memory from the flat list to avoid recursive SQL.
  """
  def list_comments_tree(case_id) do
    list_comments(case_id)
    |> build_tree(nil)
  end

  defp build_tree(comments, parent_id) do
    comments
    |> Enum.filter(fn c -> c.parent_id == parent_id end)
    |> Enum.map(fn c -> {c, build_tree(comments, c.id)} end)
  end

  def count_comments(case_id) do
    CaseComment
    |> where([c], c.case_id == ^case_id and c.is_deleted == false)
    |> Repo.aggregate(:count, :id)
  end

  def create_comment(attrs) do
    %CaseComment{}
    |> CaseComment.changeset(attrs)
    |> Repo.insert()
    |> broadcast_comment(:comment_added)
  end

  def change_case(%Case{} = case_struct, attrs \\ %{}) do
    Case.create_changeset(case_struct, attrs)
  end

  # ER Consultant approve/reject
  def update_case_er(%Case{} = case_record, attrs) do
    case_record
    |> Ecto.Changeset.change(attrs)
    |> Repo.update()
    |> broadcast(:case_er_updated)
  end

  # Cardiologist approve/reject
  def update_case_cardiology(%Case{} = case_record, attrs) do
    case_record
    |> Ecto.Changeset.change(attrs)
    |> Repo.update()
    |> broadcast(:case_cardiology_updated)
  end

  # Eligibility: assign MRN
  def update_case_eligibility(%Case{} = case_record, attrs) do
    case_record
    |> Ecto.Changeset.change(attrs)
    |> Repo.update()
    |> broadcast(:case_eligibility_updated)
  end

  # EMS: dispatch
  def update_case_ems(%Case{} = case_record, attrs) do
    case_record
    |> Ecto.Changeset.change(attrs)
    |> Repo.update()
    |> broadcast(:case_ems_dispatched)
  end

  # Cath Lab: update preparation status
  def update_case_cath_lab(%Case{} = case_record, attrs) do
    case_record
    |> Ecto.Changeset.change(attrs)
    |> Repo.update()
    |> broadcast(:case_cath_lab_updated)
  end

  # EMS: update live GPS location (high frequency, no full reload)
  def update_ems_location(%Case{} = case_record, lat, lng) do
    case_record
    |> Ecto.Changeset.change(%{
      ems_lat: lat,
      ems_lng: lng,
      ems_location_updated_at: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
    })
    |> Repo.update()
    |> broadcast(:ems_location_updated)
  end
end
