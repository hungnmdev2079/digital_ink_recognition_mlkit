# Opt-in Podfile helper that lets Google ML Kit build and run on Apple Silicon
# iOS 26+ simulators and physical devices from the same Pods installation.
# The per-build script phase relabels the arm64 slice to match the target.
# Upstream Google issue: https://issuetracker.google.com/issues/178965151

require 'fileutils'

DIGITAL_INK_MLKIT_STATE_DIR = 'DigitalInkMLKitAppleSiliconSimulator'.freeze
DIGITAL_INK_MLKIT_PATCHER = 'patch_arm64_simulator.py'.freeze
DIGITAL_INK_MLKIT_PHASE_NAME =
  '[Digital Ink ML Kit] Relabel arm64 slice for current platform'.freeze
DIGITAL_INK_MLKIT_EXCLUDED_RE =
  /^(\s*EXCLUDED_ARCHS\[sdk=iphonesimulator\*\]\s*=\s*)(.*?)\s*$/

def digital_ink_mlkit_apple_silicon_simulator_patch(installer)
  pods_dir = File.expand_path(installer.sandbox.root.to_s)
  framework_dirs = Dir.glob(File.join(pods_dir, '{MLKit*,MLImage*}'))
                      .select { |directory| File.directory?(directory) }
  return if framework_dirs.empty?

  digital_ink_mlkit_copy_patcher(pods_dir)
  digital_ink_mlkit_strip_simulator_arm64_exclusion(pods_dir)
  digital_ink_mlkit_install_build_phase(installer)
  installer.pods_project.save

  Pod::UI.puts ''
  Pod::UI.puts(
    "[digital_ink_recognition_mlkit] Apple Silicon simulator support enabled " \
    "for #{framework_dirs.size} framework(s) (auto-toggles per build).",
  )
rescue StandardError => error
  raise(
    '[digital_ink_recognition_mlkit] failed to enable Apple Silicon ' \
    "simulator support: #{error.message}",
  )
end

def digital_ink_mlkit_copy_patcher(pods_dir)
  state_dir = File.join(pods_dir, DIGITAL_INK_MLKIT_STATE_DIR)
  FileUtils.rm_rf(state_dir)
  FileUtils.mkdir_p(state_dir)
  FileUtils.cp(File.expand_path(DIGITAL_INK_MLKIT_PATCHER, __dir__), state_dir)
end

def digital_ink_mlkit_strip_simulator_arm64_exclusion(pods_dir)
  Dir.glob(File.join(pods_dir, 'Target Support Files', '**', '*.xcconfig')).each do |xcconfig|
    changed = false
    new_text = File.read(xcconfig).each_line.map do |line|
      match = line.match(DIGITAL_INK_MLKIT_EXCLUDED_RE)
      next line unless match

      tokens = match[2].split(/\s+/).reject(&:empty?)
      next line unless tokens.include?('arm64')

      changed = true
      kept = tokens.reject { |token| token == 'arm64' }
      kept.empty? ? '' : "#{match[1]}#{kept.join(' ')}\n"
    end.join
    File.write(xcconfig, new_text) if changed
  end
end

def digital_ink_mlkit_install_build_phase(installer)
  script = <<~SH
    set -euo pipefail
    : "${PLATFORM_NAME:?PLATFORM_NAME is not set}"
    : "${SRCROOT:?SRCROOT is not set}"
    /usr/bin/env python3 "${SRCROOT}/#{DIGITAL_INK_MLKIT_STATE_DIR}/#{DIGITAL_INK_MLKIT_PATCHER}" \\
      --platform "${PLATFORM_NAME}" \\
      --pods-root "${SRCROOT}"
  SH

  installer.aggregate_targets.each do |aggregate|
    target = installer.pods_project.targets.find { |item| item.name == aggregate.label }
    next unless target

    phase = target.shell_script_build_phases.find { |item| item.name == DIGITAL_INK_MLKIT_PHASE_NAME }
    phase ||= target.new_shell_script_build_phase(DIGITAL_INK_MLKIT_PHASE_NAME)
    phase.shell_path = '/bin/sh'
    phase.shell_script = script
    phase.always_out_of_date = '1' if phase.respond_to?(:always_out_of_date=)
  end
end
