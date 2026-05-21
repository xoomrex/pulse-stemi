defmodule Stemi.Cases.Case do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "cases" do
    field :case_number, :integer, read_after_writes: true
    field :patient_id, :string
    field :ecg_photo_url, :string
    field :id_photo_url, :string
    field :status, :string, default: "pending_er"

    # virtual: used by the PHC submission form. On insert we turn this into a
    # root case_comment record so it threads naturally with later replies.
    field :initial_comment, :string, virtual: true

    # ER Consultant decision
    field :er_decision, :string
    field :er_decided_at, :utc_datetime

    # Cardiology decision
    field :cardiology_decision, :string
    field :cardiology_decided_at, :utc_datetime

    # Eligibility
    field :mrn_number, :string
    field :eligibility_decided_at, :utc_datetime

    # EMS
    field :ems_dispatched_at, :utc_datetime
    field :ems_lat, :float
    field :ems_lng, :float
    field :ems_location_updated_at, :naive_datetime

    # Cath Lab
    field :cath_lab_status, :string, default: "pending"
    field :cath_lab_confirmed_at, :utc_datetime

    field :is_deleted, :boolean, default: false

    belongs_to :phc_user, Stemi.Accounts.User
    belongs_to :phc_hospital, Stemi.Hospitals.Hospital, type: :integer
    belongs_to :er_consultant, Stemi.Accounts.User
    belongs_to :cardiologist, Stemi.Accounts.User
    belongs_to :eligibility, Stemi.Accounts.User
    belongs_to :ems_user, Stemi.Accounts.User
    belongs_to :cath_lab_user, Stemi.Accounts.User

    has_many :case_comments, Stemi.Cases.CaseComment

    timestamps(type: :utc_datetime)
  end

  @statuses ~w(pending_er er_approved er_rejected pending_cardio approved rejected dispatched completed)

  def statuses, do: @statuses

  def display_id(%__MODULE__{case_number: n}) when is_integer(n) do
    "STEMI-#{String.pad_leading(Integer.to_string(n), 3, "0")}"
  end
  def display_id(_), do: "STEMI-???"

  def create_changeset(case_struct, attrs) do
    case_struct
    |> cast(attrs, [:patient_id, :ecg_photo_url, :id_photo_url, :initial_comment, :phc_user_id, :phc_hospital_id])
    |> validate_required([:phc_user_id])
    |> validate_length(:patient_id, max: 50)
    |> validate_length(:initial_comment, max: 2000)
  end
end
