defmodule Stemi.Cases.CaseComment do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "case_comments" do
    field :body, :string
    field :is_deleted, :boolean, default: false

    belongs_to :case, Stemi.Cases.Case
    belongs_to :user, Stemi.Accounts.User
    belongs_to :parent, __MODULE__, foreign_key: :parent_id
    has_many :replies, __MODULE__, foreign_key: :parent_id

    timestamps(type: :utc_datetime)
  end

  def changeset(comment, attrs) do
    comment
    |> cast(attrs, [:body, :case_id, :user_id, :parent_id, :is_deleted])
    |> validate_required([:body, :case_id])
    |> validate_length(:body, min: 1, max: 2000)
  end
end
