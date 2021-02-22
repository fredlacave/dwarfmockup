#! /usr/local/bin/ruby
# encoding: utf-8

require_relative 'messagebox'
require_relative 'inputbox'
require_relative 'fileinputbox'

require_relative '../misc/preferences'
require_relative '../grids/blueprint'

class DialogChain
  def initialize(window)
    @window = window
    begin_chain
  end
end

class ConfirmChain < DialogChain
  def begin_chain
    if @window.saved
      confirm_check(:yes)
    else
      YesNoBox.new(@window, 'You have unsaved modifications.  Do you want to continue ?') { |result| confirm_check(result) }
    end
  end

  def confirm_check(result)
    return if result == :no
    confirm_chain
  end

  def confirm_chain
    raise
  end
end


class SaveChain < DialogChain
  def begin_chain
    FileInputBox.new(@window, 'Save as :', @window.blueprint.name, Preferences.instance.prefs[:blueprints_dir], 'csv', Blueprint::PHASES_RE) { |name, cancel| pre_save_file(name, cancel) }
  end

  def pre_save_file(name, cancel)
    return if cancel
    if name != @window.blueprint.name && Blueprint.new(name).exists?
      YesNoCancelBox.new(@window, "File '#{name}' already exists.  Do you want to overwrite it ?") { |result| confirm_save_file(result, name) }
    else
      confirm_save_file(:yes, name)
    end
  end

  def confirm_save_file(result, name)
    return if result == :cancel
    if result == :no
      begin_chain
    else
      InputBox.new(@window, 'Design comment :', @window.blueprint.comment) { |comment, cancel| save_file(name, comment, cancel) }
    end
  end

  def save_file(name, comment, cancel)
    return if cancel
    @window.blueprint.name = name
    @window.blueprint.comment = comment
    @window.blueprint.save_to_csv
    @window.saved = true
  end
end

class LoadChain < ConfirmChain
  def confirm_chain
    FileInputBox.new(@window, 'Load :', @window.blueprint.name, Preferences.instance.prefs[:blueprints_dir], 'csv', Blueprint::PHASES_RE) { |name, cancel| load_file(name, cancel) }
  end

  def load_file(name, cancel)
    return if cancel
    blueprint = Blueprint.new(name).load_from_csv(name)
    if blueprint.valid?
      @window.blueprint = blueprint
      @window.reinit
    else
      InfoBox.new(@window, 'File not found or in incorrect format.')
    end
  end
end

class AltLoadChain < DialogChain
  def begin_chain
    FileInputBox.new(@window, 'Load :', @window.blueprint.name, Preferences.instance.prefs[:blueprints_dir], 'csv', Blueprint::PHASES_RE) { |name, cancel| load_file(name, cancel) }
  end

  def load_file(name, cancel)
    return if cancel
    blueprint = Blueprint.new(name, nil, true).load_from_csv(name)
    if blueprint.valid?
      @window.copy = blueprint.stack #.extract_range(*blueprint.stack.used_range)
      @window.do_paste
    else
      InfoBox.new(@window, 'File not found or in incorrect format.')
    end
  end
end

class NewChain < ConfirmChain
  def confirm_chain
    @window.reinit
    @window.setup_grid
  end
end

class QuitChain < ConfirmChain
  def confirm_chain
    @window.close
  end
end
