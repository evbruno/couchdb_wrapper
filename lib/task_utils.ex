defmodule TaskUtils do
  def start(dat_file) do
    [animate_spinner_pid(), update_stats_pid(dat_file)]
  end

  def has_previous_run?(task_name, database) do
    dat_file = ".#{task_name}.dat"

    if File.exists?(dat_file) do
      handle_previous_run(true, dat_file, File.read!(dat_file) |> String.trim(), task_name, database)
    else
      handle_no_previous_run(task_name, database, dat_file)
    end
  end

  defp handle_previous_run(true, file, content, task_name, database) do
    msg = """
    Previous run detected from file "#{file}".
    Resume #{task_name} on #{database}, from last offset: #{content}
    Continue?
    """

    confirm_action(msg)
    {true, file, content}
  end

  defp handle_no_previous_run(task_name, database, dat_file) do
    Mix.shell().info("Going to run the task #{task_name} on #{database}")
    confirm_action("Are you sure?")
    {false, dat_file, nil}
  end

  defp confirm_action(message) do
    unless Mix.shell().yes?(message) do
      Mix.shell().info("Aborted.")
      System.halt(1)
    end
  end

  def stop(pids) do
    Enum.each(pids, &send(&1, :done))
  end

  def update_stats(dat_file) do
    receive do
      {:update_last, value} ->
        File.write!(dat_file, to_string(value))
        update_stats(dat_file)

      :done ->
        File.rm(dat_file)

      _ ->
        update_stats(dat_file)
    end
  end

  defp animate_spinner do
    chars = ["-", "\\", "|", "/"]
    Enum.each(Stream.cycle(chars), &animate_char/1)
  end

  defp animate_char(char) do
    IO.write("\r" <> char)
    Process.sleep(200)
  end

  def step(stream, pids, id_key, bucket_size \\ 5_000) do
    [_, tracker_pid] = pids

    stream
    |> Stream.with_index(fn elem, idx ->
      track_progress(idx, elem, tracker_pid, id_key, bucket_size)
    end)
  end

  defp track_progress(idx, elem, tracker_pid, id_key, bucket_size) do
    print_feedback(idx, bucket_size)

    if rem(idx, 100) == 0 do
      last_id = Map.get(elem, id_key)
      send(tracker_pid, {:update_last, last_id})
    end

    elem
  end

  defp print_feedback(idx, bucket_size) do
    if idx > 0 and rem(idx, bucket_size) == 0 do
      IO.puts("\r[+ #{idx}]")
    end
  end

  defp animate_spinner_pid() do
    spawn(&animate_spinner/0)
  end

  defp update_stats_pid(dat_file) do
    spawn(fn -> update_stats(dat_file) end)
  end
end
