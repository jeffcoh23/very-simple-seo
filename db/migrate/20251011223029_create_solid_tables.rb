# frozen_string_literal: true

class CreateSolidTables < ActiveRecord::Migration[8.0]
  def change
    # ============================================================================
    # SOLID CACHE
    # ============================================================================
    create_table :solid_cache_entries, force: :cascade do |t|
      t.binary :key, limit: 1024, null: false
      t.binary :value, limit: 536870912
      t.datetime :created_at, null: false
      t.integer :key_hash, limit: 8, null: false
      t.integer :byte_size, limit: 4, null: false

      t.index [:key_hash, :byte_size], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
      t.index [:key_hash], name: "index_solid_cache_entries_on_key_hash", unique: true
    end

    # ============================================================================
    # SOLID CABLE
    # ============================================================================
    create_table :solid_cable_messages, force: :cascade do |t|
      t.binary :channel, limit: 1024, null: false
      t.binary :payload, limit: 536870912, null: false
      t.datetime :created_at, null: false
      t.integer :channel_hash, limit: 8, null: false

      t.index [:channel], name: "index_solid_cable_messages_on_channel"
      t.index [:created_at], name: "index_solid_cable_messages_on_created_at"
      t.index [:channel_hash], name: "index_solid_cable_messages_on_channel_hash"
    end

    # ============================================================================
    # SOLID QUEUE
    # ============================================================================

    # Main jobs table
    create_table :solid_queue_jobs, force: :cascade do |t|
      t.string :queue_name, null: false
      t.string :class_name, null: false, limit: 200
      t.text :arguments
      t.integer :priority, default: 0, null: false
      t.string :active_job_id, limit: 200
      t.datetime :scheduled_at
      t.datetime :finished_at
      t.string :concurrency_key, limit: 200
      t.timestamps

      t.index [:active_job_id], name: "index_solid_queue_jobs_on_active_job_id"
      t.index [:class_name], name: "index_solid_queue_jobs_on_class_name"
      t.index [:finished_at], name: "index_solid_queue_jobs_on_finished_at"
      t.index [:queue_name, :finished_at], name: "index_solid_queue_jobs_for_filtering"
      t.index [:scheduled_at, :finished_at], name: "index_solid_queue_jobs_for_alerting"
    end

    # Scheduled executions
    create_table :solid_queue_scheduled_executions, force: :cascade do |t|
      t.references :job, null: false, foreign_key: { to_table: :solid_queue_jobs, on_delete: :cascade }
      t.string :queue_name, null: false
      t.integer :priority, default: 0, null: false
      t.datetime :scheduled_at, null: false
      t.timestamps

      t.index [:scheduled_at, :priority, :job_id], name: "index_solid_queue_dispatch_all"
    end

    # Ready executions
    create_table :solid_queue_ready_executions, force: :cascade do |t|
      t.references :job, null: false, foreign_key: { to_table: :solid_queue_jobs, on_delete: :cascade }
      t.string :queue_name, null: false
      t.integer :priority, default: 0, null: false
      t.timestamps

      t.index [:priority, :job_id], name: "index_solid_queue_poll_all"
      t.index [:queue_name, :priority, :job_id], name: "index_solid_queue_poll_by_queue"
    end

    # Claimed executions
    create_table :solid_queue_claimed_executions, force: :cascade do |t|
      t.references :job, null: false, foreign_key: { to_table: :solid_queue_jobs, on_delete: :cascade }
      t.bigint :process_id
      t.timestamps

      t.index [:process_id, :job_id], name: "index_solid_queue_claimed_executions"
    end

    # Failed executions
    create_table :solid_queue_failed_executions, force: :cascade do |t|
      t.references :job, null: false, foreign_key: { to_table: :solid_queue_jobs, on_delete: :cascade }
      t.text :error
      t.integer :attempts, default: 0, null: false
      t.timestamps
    end

    # Blocked executions
    create_table :solid_queue_blocked_executions, force: :cascade do |t|
      t.references :job, null: false, foreign_key: { to_table: :solid_queue_jobs, on_delete: :cascade }
      t.string :queue_name, null: false
      t.integer :priority, default: 0, null: false
      t.string :concurrency_key, null: false
      t.datetime :expires_at, null: false
      t.timestamps

      t.index [:concurrency_key, :priority, :job_id], name: "index_solid_queue_blocked_executions"
      t.index [:expires_at], name: "index_solid_queue_blocked_executions_on_expires_at"
    end

    # Processes
    create_table :solid_queue_processes, force: :cascade do |t|
      t.string :kind, null: false
      t.datetime :last_heartbeat_at, null: false
      t.bigint :supervisor_id
      t.integer :pid, null: false
      t.string :hostname
      t.text :metadata
      t.timestamps

      t.index [:last_heartbeat_at], name: "index_solid_queue_processes_on_last_heartbeat_at"
      t.index [:supervisor_id], name: "index_solid_queue_processes_on_supervisor_id"
    end

    # Pauses
    create_table :solid_queue_pauses, force: :cascade do |t|
      t.string :queue_name, null: false
      t.timestamps

      t.index [:queue_name], name: "index_solid_queue_pauses_on_queue_name", unique: true
    end

    # Recurring executions
    create_table :solid_queue_recurring_executions, force: :cascade do |t|
      t.references :job, null: false, foreign_key: { to_table: :solid_queue_jobs, on_delete: :cascade }
      t.string :task_key, null: false
      t.datetime :run_at, null: false
      t.timestamps

      t.index [:task_key, :run_at], name: "index_solid_queue_recurring_executions", unique: true
    end

    # Recurring tasks
    create_table :solid_queue_recurring_tasks, force: :cascade do |t|
      t.string :key, null: false
      t.string :schedule, null: false
      t.string :command, limit: 2048
      t.string :class_name, limit: 200
      t.text :arguments
      t.string :queue_name
      t.integer :priority, default: 0
      t.boolean :static, default: true, null: false
      t.text :description
      t.timestamps

      t.index [:key], name: "index_solid_queue_recurring_tasks_on_key", unique: true
      t.index [:static], name: "index_solid_queue_recurring_tasks_on_static"
    end

    # Semaphores
    create_table :solid_queue_semaphores, force: :cascade do |t|
      t.string :key, null: false, limit: 200
      t.integer :value, default: 1, null: false
      t.datetime :expires_at, null: false
      t.timestamps

      t.index [:expires_at], name: "index_solid_queue_semaphores_on_expires_at"
      t.index [:key, :value], name: "index_solid_queue_semaphores_on_key_and_value"
      t.index [:key], name: "index_solid_queue_semaphores_on_key", unique: true
    end
  end
end
