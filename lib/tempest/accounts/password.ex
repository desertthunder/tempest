defmodule Tempest.Accounts.Password do
  @moduledoc """
  Password hashing boundary.

  TODO: validation could be stricter
  """

  @min_length 8
  @max_length 256

  def validate(password) when is_binary(password) do
    length = String.length(password)

    cond do
      length < @min_length -> {:error, "password must be at least #{@min_length} characters"}
      length > @max_length -> {:error, "password must be at most #{@max_length} characters"}
      true -> :ok
    end
  end

  def validate(_password), do: {:error, "password is required"}

  def hash(password) when is_binary(password), do: Argon2.hash_pwd_salt(password)

  def verify(password, hash) when is_binary(password) and is_binary(hash) do
    Argon2.verify_pass(password, hash)
  end

  def verify(_password, _hash) do
    Argon2.no_user_verify()
    false
  end
end
