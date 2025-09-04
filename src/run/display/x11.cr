require "x11"
require "xtst"
require "./display-adapter"

at_exit { GC.collect }

module X11::C
	# Infer a long list of key names from lib/x11/src/x11/c/keysymdef.cr, stripped from XK_ and underscores.
	# Seems to be necessary because XStringToKeysym is always case sensitive (?)
	# In our X11 key handling, we only deal with lowercase chars.
	def self.ahk_key_name_to_keysym_generic
		{{
			@type.constants # TODO: possible to declare this outside of the module?
				.select { |c| c.stringify.starts_with?("XK_") } # && c.underlying-var-type.is_a?(Int32) < TODO: how to, so the bools are skipped? (and `|| ! sym.is_a?(Int32)` can be removed)
				# Hash lookups are expensive, they take about 3 ms each here (!) but I'm not really sure
				# we can do anything about it: NamedTuple would be much better for this use case as it's
				# stack-allocated and tailored towards values which are known at runtime, but it's
				# limited to 300 items only. I guess a solution would be a manually curated, reasonably
				# ordered list (perhaps case statement)... I now opted for adding a cache below, which
				# is definitely the fastest solution as the program runs over time (see _cache)
				.reduce({} of String => Int32) do |acc, const_name|
					key_name = const_name.stringify[3..]
					key_name = key_name.downcase if key_name.size > 1
					acc[key_name.gsub(/_/, "")] = const_name
					acc[key_name] = const_name
					acc
				end
		}}
	end
	# these are ahk-specific
	def self.ahk_key_name_to_keysym_custom
		{
			"enter" => XK_Return,
			"esc" => XK_Escape,
			"bs" => XK_BackSpace,
			"del" => XK_Delete,
			"ins" => XK_Insert,
			"pgup" => XK_Page_Up,
			"pgdn" => XK_Page_Down,
			"printscreen" => XK_Print,

			# Could not find the constants for these
			"lbutton" => 1,
			"rbutton" => 3,
			"mbutton" => 2,
			"wheeldown" => 5,
			"wheelup" => 4,
			"wheelleft" => 6, # [v1.0.48+]
			"wheelright" => 7, # [v1.0.48+]
			"xbutton1" => 8,
			"xbutton2" => 9,

			# TODO: Joystick buttons

			# The following special keys were determined either using `xev` or with https://github.com/qtile/qtile/blob/master/libqtile/backend/x11/xkeysyms.py (x11 must have them somewhere too??). TODO: These are mostly untested out of a loack of fitting keyboard.
			"volume_mute" => 0x1008ff12, # XF86AudioMute
			"volume_down" => 0x1008ff11, # XF86AudioLowerVolume
			"volume_up" => 0x1008ff13, # XF86AudioRaiseVolume
			"browser_back" => 0x1008ff26, # XF86Back
			"browser_forward" => 0x1008ff27, # XF86Forward
			"browser_refresh" => 0x1008ff73, # XF86Reload
			"browser_search" => 0x1008ff1b, # XF86Search
			"browser_homepage" => 0x1008ff18, # XF86HomePage
			"browser_stop" => 0x1008FF28, # XF86Stop
			"browser_favorites" => 0x1008FF30, # XF86Favorites
			"media_next" => 0x1008FF17, # XF86AudioNext
			"media_prev" => 0x1008FF16, # XF86AudioPrev
			"media_stop" => 0x1008FF15, # XF86AudioStop
			"media_play_pause" => 0x1008FF14, # XF86AudioPlay ?or? XF86AudioPause 0x1008FF31
			"launch_mail" => 0x1008FF19, # XF86Mail
			"launch_media" => 0x1008FF32, # XF86AudioMedia
			"launch_app1" => 0x1008FF5D, # XF86Explorer
			"launch_app2" => 0x1008FF1D, # XF86Calculator
			"ctrlbreak" => XK_Break,
			"sleep" => 0x1008FF2F, # XF86Sleep
			"numpaddiv" => XK_KP_Divide,
			"numpadmult" => XK_KP_Multiply,
			"numpadadd" => XK_KP_Add,
			"numpadsub" => XK_KP_Subtract,
			"numpadenter" => XK_KP_Enter,
			"numpaddel" => XK_KP_Delete,
			"numpadins" => XK_KP_Insert,
			"numpadclear" => XK_KP_Begin,
			"numpadup" => XK_KP_Up,
			"numpaddown" => XK_KP_Down,
			"numpadleft" => XK_KP_Left,
			"numpadright" => XK_KP_Right,
			"numpadhome" => XK_KP_Home,
			"numpadend" => XK_KP_End,
			"numpadpgup" => XK_KP_Page_Up,
			"numpadpgdn" => XK_KP_Page_Down,
			"numpad0" => XK_KP_0,
			"numpad1" => XK_KP_1,
			"numpad2" => XK_KP_2,
			"numpad3" => XK_KP_3,
			"numpad4" => XK_KP_4,
			"numpad5" => XK_KP_5,
			"numpad6" => XK_KP_6,
			"numpad7" => XK_KP_7,
			"numpad8" => XK_KP_8,
			"numpad9" => XK_KP_9,
			"numpaddot" => XK_KP_Decimal,
			"appskey" => XK_Menu,
			"lwin" => XK_Super_L,
			"rwin" => XK_Super_R,
			"control" => XK_Control_L,
			"ctrl" => XK_Control_L,
			"lcontrol" => XK_Control_L,
			"lctrl" => XK_Control_L,
			"rcontrol" => XK_Control_R,
			"rctrl" => XK_Control_R,
			"shift" => XK_Shift_L,
			"lshift" => XK_Shift_L,
			"rshift" => XK_Shift_R,
			"alt" => XK_Alt_L,
			"lalt" => XK_Alt_L,
			"ralt" => XK_Alt_R,
			"scrolllock" => XK_Scroll_Lock,
			"capslock" => XK_Caps_Lock,
			"numlock" => XK_Num_Lock,

			# Printable non-letters, symbols ;%@ etc.: Often their unicode ord is equal
			# to the keysym so the fallback should work. Below are only known exceptions
			"\n" => XK_Return,
			"\t" => XK_Tab,

			# TODO:
			# RAlt -- Note: If your keyboard layout has AltGr instead of RAlt, you can probably use it as a hotkey prefix via <^>! as described here. In addition, "LControl & RAlt::" would make AltGr itself into a hotkey.
		}
	end
end

module Run
	# Responsible for registering hotkeys to the X11 server,
	# listening to all events and calling threads on hotkey trigger
	# and calling given event listeners.
	class X11 < DisplayAdapter
		# include ::X11 # removed because of https://github.com/TamasSzekeres/x11-cr/issues/15 and who knows what else. < TODO: is resolved

		@root_win = 0_u64
		@_NET_ACTIVE_WINDOW : ::X11::C::Atom
		@last_active_window = 0_u64
		getter display : ::X11::Display
		getter root_win : ::X11::Window
		# Multiple threads can access this X11 instance, but to avoid dead locks surrounding
		# the blocking event loop, every state altering method needs to be synchronized with mutex:
		@mutex = Mutex.new
		@record_context : ::Xtst::LibXtst::RecordContext?
		@record : ::Xtst::RecordExtension?
		@runner : Run::Runner
		@grab_from_root : Bool

		def initialize(@runner)
			::X11::C::X.init_threads # because otherwise crashes occur in some mysterious cases

			set_error_handler

			@display = ::X11::Display.new
			@root_win = @display.root_window @display.default_screen_number
			{% if ! flag?(:release) %}
				puts "[debug] x11: root_win = #{@root_win}"
			{% end %}
			@_NET_ACTIVE_WINDOW = @display.intern_atom("_NET_ACTIVE_WINDOW", true)
			{% if ! flag?(:release) %}
				puts "[debug] x11: _NET_ACTIVE_WINDOW = #{@_NET_ACTIVE_WINDOW}"
			{% end %}
			root_win_attributes = ::X11::SetWindowAttributes.new
			root_win_attributes.event_mask = ::X11::PropertyChangeMask
			# So we get notified of active window change
			@display.change_window_attributes(@root_win, ::X11::C::CWEventMask, root_win_attributes)
			@last_active_window = active_window()
			@grab_from_root = @runner.settings.x11_grab_from_root

			begin
				@record = record = ::Xtst::RecordExtension.new
				record_range = record.create_range
				record_range.device_events.first = ::X11::KeyPress
				record_range.device_events.last = ::X11::ButtonRelease
				@record_context = record.create_context(record_range)
			rescue e
				# TODO: msgbox?
				STDERR.puts e
				STDERR.puts "The script will continue but some features (esp. Hotstrings) may not work. Please also consider opening an issue at https://github.com/phil294/ahk_x11 and tell us about your system details."
			end
		end

		private def active_window
			# TODO: manybe use @x_do.active_window if it's similarly fast? (evdev branch)
			return 0_u64 if @_NET_ACTIVE_WINDOW < 1
			prop = @display.window_property(@root_win, @_NET_ACTIVE_WINDOW, 0_i64, 1_i64, false, ::X11::C::XA_WINDOW.to_u64)
			nitems = prop[:nitems]
			data = prop[:prop].unsafe_as(Pointer(UInt64))
			if data.null? || nitems.nil? || nitems < 1
				{% if ! flag?(:release) %}
					puts "[debug] x11: active window detection: _NET_ACTIVE_WINDOW returned NULL prop data"
				{% end %}
				return 0_u64
			end
			win = data.value
			{% if ! flag?(:release) %}
				puts "[debug] x11: active window detection: #{win}"
			{% end %}
			win
		end

		def finalize
			@mutex.lock
			@display.close
			@record.not_nil!.close if @record
		end

		def keysym_to_keycode(sym : UInt64)
			@display.keysym_to_keycode(sym)
		end

		# See comments inside `ahk_key_name_to_keysym_generic` for why this is necessary.
		# Esp. for stuff like `Input` with many EndKeys parameter, this cache is quite
		# useful, as it speed it up from 0.2s by factor 1,000
		@@ahk_key_name_to_keysym_cache = {} of String => (Int32 | Bool)

		def self.ahk_key_name_to_keysym(key_name)
			return nil if key_name.empty?
			cached = @@ahk_key_name_to_keysym_cache[key_name]?
			return cached if cached
			lookup = ::X11::C.ahk_key_name_to_keysym_custom[key_name]? || ::X11::C.ahk_key_name_to_keysym_generic[key_name]? || ::X11::C.ahk_key_name_to_keysym_custom[key_name.downcase]? || ::X11::C.ahk_key_name_to_keysym_generic[key_name.downcase]?
			if lookup
				@@ahk_key_name_to_keysym_cache[key_name] = lookup
				return lookup
			end
			return nil if key_name.size > 1
			char = key_name[0]
			return nil if char >= 'A' && char <= 'Z' || char >= 'a' && char <= 'z'
			# This fallback may fail but it's very likely this is the correct match now.
			# This is the normal path for special chars like . @ $ etc.
			ord = char.ord
			@@ahk_key_name_to_keysym_cache[key_name] = ord
			ord
		end

		# Makes sure the program doesn't exit when a Hotkey is not free for grabbing
		private def set_error_handler
			# Cannot use *any* outside variables here because any closure somehow makes set_error_handler never return, even with uninitialized (?why?), so we cannot set variables, show popup, nothing
			::X11.set_error_handler ->(display : ::X11::C::X::PDisplay, error_event : ::X11::C::X::PErrorEvent) do
				buffer = Array(UInt8).new 1024
				::X11::C::X.get_error_text display, error_event.value.error_code, buffer.to_unsafe, 1024
				error_message = String.new buffer.to_unsafe
				if error_event.value.error_code == 10
					# Grabbing failed, most likely because already grabbed by other program / script instance
					STDERR.puts error_message + " (You can probably ignore this error)"
				else
					STDERR.puts "Display server unexpectedly failed with the following error message:\n\n#{error_message}\n\nThe script will exit."
					::exit 5
				end
				1
			end
		end

		@key_handler : Proc(::X11::KeyEvent, UInt64, Char?, Nil)?
		@flush_event_queue = Channel(Nil).new
		def run(*, key_handler)
			@key_handler = key_handler
			record = @record
			if record
				spawn same_thread: true do
					record.enable_context_async(@record_context.not_nil!) do |record_data|
						handle_record_event(record_data)
					end
					record_fd = IO::FileDescriptor.new record.data_display.connection_number
					loop do
						Crystal::EventLoop.current.wait_readable(record_fd.not_nil!)
						@mutex.lock
						record.process_replies
						@mutex.unlock
					end
				end
			end
			# Even if XTst Record obliterates the need to read key events, we still need to
			# keep the event loop running or otherwise the hotkeys aren't even grabbed
			# and use it to get updates on the active window.
			spawn same_thread: true do
				event_fd = IO::FileDescriptor.new @display.connection_number
				loop do
					# Instead of this, running `next_event` (blocking) in a loop also works but requires a separate thread.
					# But that somehow messes up `::exit` so we don't do that.
					# This very solution, `wait_readable`, has shown to *sometimes* be unreliable, i.e. hotkeys aren't
					# grabbed properly because some pending events somehow aren't visible. To solve this,
					# `flush_event_queue` is also called from a few other places.
					Crystal::EventLoop.current.wait_readable(event_fd)
					@flush_event_queue.send(nil)
				end
			end
			loop do
				while @display.pending != 0
					@mutex.lock
					event = @display.next_event
					if event.is_a?(::X11::PropertyEvent) && event.atom == @_NET_ACTIVE_WINDOW
						# focussed_win = @display.input_focus[:focus] # https://stackoverflow.com/q/31800880, https://stackoverflow.com/q/60141048
						active_win = active_window()
						if active_win != @last_active_window && active_win > 0
							active_window_before = @last_active_window
							@last_active_window = active_win
							if ! @grab_from_root
								# The mutex doesn't protect against nonsense here yet but the chance for
								# this to happen is fairly small
								spawn same_thread: true do
									@hotkeys.each { |h| ungrab_hotkey(h, from_window: active_window_before, unsubscribe: false) }
									@hotkeys.each { |h| grab_hotkey(h, subscribe: false) }
								end
							end
						end
					end
					@mutex.unlock
					if ! record
						# Misses non-grabbed keys and mouse events. It could also be done this way
						# (see old commits), but only unreliably and not worth the effort.
						if event.is_a? ::X11::KeyEvent
							handle_key_event(event)
						end
					end
				end
				@flush_event_queue.receive
			end
		end

		private def handle_record_event(record_data)
			return if record_data.category != Xtst::LibXtst::RecordInterceptDataCategory::FromServer.value
			type, keycode, repeat = record_data.data
			state = record_data.data[28]
			return if repeat == 1
			_key_event = ::X11::KeyEvent.new
			_key_event.display = @display
			_key_event.type = type
			_key_event.keycode = keycode
			_key_event.state = state
			if type >= 4 # mouse button. keycode will be 1-9
				# pretend that keysym = keycode
				@key_handler.not_nil!.call(_key_event, keycode.to_u64, nil)
			else
				handle_key_event(_key_event)
			end
		end

		private def handle_key_event(key_event)
			state_bck = key_event.state
			# We want to receive a usable char even when e.g. Ctrl is pressed, currently only
			# because of the shift/uppercase detection below. Shift needs to stay in state though
			# to differentiate e.g. 2 vs @ and mod2 = num lock for num numbers # TODO < add auto num number hotkey test
			key_event.state = key_event.state & (::X11::ShiftMask | ::X11::Mod2Mask)
			lookup = key_event.lookup_string
			key_event.state = state_bck
			char = lookup[:string][0]?
			keysym = lookup[:keysym]
			# We may have e.g. grabbed *a (so including Shift + lowercase a) but the reported
			# event here will return Shift + uppercase A. We'll deal with lowercase only.
			if char && char.downcase != char
				char = char.downcase
				keysym = Run::X11.ahk_key_name_to_keysym(char.to_s)
				# TODO: like ahk-string.cr
				raise Run::RuntimeException.new "Unexpected keysym #{keysym} is uppercase but can't be mapped to lowercase" if ! keysym || ! keysym.is_a?(Int32)
			end
			@key_handler.not_nil!.call(key_event, keysym.to_u64, char)
		end

		private def grab_window
			# Last can be 0 in rare cases such as on Solus KDE after hotkey press of *other* script
			# without grab_from_root set
			if @grab_from_root || @last_active_window == 0
				@root_win
			else
				@last_active_window
			end
		end

		# It's easier to just grab on the root window once, but by repeatedly reattaching to the respectively currently
		# active window, we avoid losing focus from the active window while a grabbed key is pressed down.
		# https://stackoverflow.com/a/69216578/3779853
		# This helps avoiding various popups and menus from auto-closing on hotkey press.
		# Because of this, this driver needs to maintain its own list of hotkeys.
		# This behavior depends on `@grab_from_root`.
		@hotkeys = [] of Hotkey
		# :ditto:
		def grab_hotkey(hotkey, *, subscribe = true)
			@mutex.lock
			@hotkeys << hotkey if subscribe && hotkey.keysym >= 10
			hotkey.modifier_variants.each do |mod|
				if hotkey.keysym < 10
					@display.grab_button(hotkey.keysym.to_u32, mod, grab_window: @root_win, owner_events: true, event_mask: ::X11::ButtonPressMask.to_u32, pointer_mode: ::X11::GrabModeAsync, keyboard_mode: ::X11::GrabModeAsync, confine_to: ::X11::None.to_u64, cursor: ::X11::None.to_u64)
				else
					@display.grab_key(hotkey.keycode, mod, grab_window: grab_window, owner_events: true, pointer_mode: ::X11::GrabModeAsync, keyboard_mode: ::X11::GrabModeAsync)
				end
			end
			@mutex.unlock
			@flush_event_queue.send(nil)
		end
		# :ditto:
		def ungrab_hotkey(hotkey, *, from_window = @last_active_window, unsubscribe = true)
			@mutex.lock
			@hotkeys.delete hotkey if unsubscribe
			hotkey.modifier_variants.each do |mod|
				if hotkey.keysym < 10
					@display.ungrab_button(hotkey.keycode, mod, grab_window: @root_win)
				else
					@display.ungrab_key(hotkey.keycode, mod, grab_window: @grab_from_root ? @root_win : from_window)
				end
			end
			@mutex.unlock
			@flush_event_queue.send(nil)
		end
		def grab_keyboard
			@mutex.lock
			@display.grab_keyboard(grab_window: grab_window, owner_events: true, pointer_mode: ::X11::GrabModeAsync, keyboard_mode: ::X11::GrabModeAsync, time: ::X11::CurrentTime)
			@mutex.unlock
			@flush_event_queue.send(nil)
		end
		def ungrab_keyboard
			@mutex.lock
			@display.ungrab_keyboard(time: ::X11::CurrentTime)
			@mutex.unlock
			@flush_event_queue.send(nil)
		end
		def grab_pointer
			@mutex.lock
			@display.grab_pointer(grab_window: grab_window, owner_events: true, pointer_mode: ::X11::GrabModeAsync, keyboard_mode: ::X11::GrabModeAsync, time: ::X11::CurrentTime, event_mask: 0_u32, confine_to: 0_u64, cursor: 0_u64)
			@mutex.unlock
			@flush_event_queue.send(nil)
		end
		def ungrab_pointer
			@mutex.lock
			@display.ungrab_pointer(time: ::X11::CurrentTime)
			@mutex.unlock
			@flush_event_queue.send(nil)
		end
		def block_input
			grab_keyboard
			grab_pointer
		end
		def unblock_input
			ungrab_keyboard
			ungrab_pointer
		end

		def show_desktop(show)
			_NET_SHOWING_DESKTOP = @display.intern_atom("_NET_SHOWING_DESKTOP", false)
    		event = ::X11::ClientMessageEvent.new
			event.type = ::X11::C::ClientMessage
    		event.window = @root_win
    		event.message_type = _NET_SHOWING_DESKTOP
    		event.format = 32
			value = show ? 1_i64 : 0_i64
			event.long_data = StaticArray[value, 0_i64, 0_i64, 0_i64, 0_i64]
			@display.send_event(@root_win, false, ::X11::C::SubstructureRedirectMask | ::X11::C::SubstructureNotifyMask, event)
			display.flush # <- I DON'T KNOW WHY BUT I WANT MY THREE HOURS BACK
		end
	end
end