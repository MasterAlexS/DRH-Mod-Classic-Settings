package mods.classic_settings;

import brain.uI.UIButton;
import facade.DBFacade;
import facade.Locale;
import openfl.display.DisplayObject;
import openfl.display.DisplayObjectContainer;
import openfl.display.MovieClip;
import openfl.filters.BitmapFilter;
import openfl.filters.DropShadowFilter;
import openfl.filters.GlowFilter;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.text.TextFormatAlign;
import settings.SettingsPopup;
import settings.view.SettingsCategoryTabs;
import settings.view.SettingsList;
import settings.view.rows.SettingRow;

/**
 * Transforms the in-game Settings popup into the classic Dungeon Rampage aesthetic.
 *
 * Core design philosophy:
 * 1. Swap the visual shell: replace the modern yellow/black hazard borders and grunge splats
 *    with the authentic wooden plank board (`popup_base`) and red ribbon banner from `db_UI_town.swf`.
 * 2. Restore classic fantasy typography: style titles and tabs in bold gold (`#FFCC00`),
 *    descriptions in warm parchment tan (`#D4C4B0`), and apply soft feathered drop shadows.
 * 3. 100% native stability: leave all functional controls (checkboxes, arrows, sliders, keys,
 *    and scrollbars) completely intact so gameplay logic and other mods work flawlessly.
 */
class SettingsReskinner {
	// Wooden board dimensions and center point, sized to comfortably frame all settings content
	static inline final BASE_WIDTH = 1360.0;
	static inline final BASE_HEIGHT = 740.0;
	static inline final BASE_CENTER_X = 425.0;
	static inline final BASE_CENTER_Y = 285.0;

	// Red ribbon banner placed across the top iron frame bar
	static inline final BANNER_WIDTH = 700.0;
	static inline final BANNER_HEIGHT = 128.0;
	static inline final BANNER_X = 425.0;
	static inline final BANNER_Y = -82.0;

	// Title TextField vertical placement and height (ample height so the default 1.0 font is never clipped)
	static inline final TITLE_Y = -147.0;
	static inline final TITLE_HEIGHT = 160.0;

	// Close button position: aligned so the center of the white 'X' sits precisely
	// at the corner intersection where the top horizontal iron bar and right vertical iron bar meet.
	static inline final CLOSE_X = 1105.0;
	static inline final CLOSE_Y = -75.0;

	// Classic Dungeon Rampage color palette
	static inline final GOLD_COLOR = 0xFFCC00; // Used for titles, category tabs, and option names
	static inline final TAN_COLOR = 0xD4C4B0;  // Warm parchment color used for option descriptions
	static inline final WHITE_COLOR = 0xFFFFFF; // Crisp white used for values and the reset button

	/**
	 * Soft feathered shadow + glow filter sets.
	 *
	 * In pre-1.0 Dungeon Rampage, text used a gentle comic shadow rather than a heavy solid outline.
	 * We achieve this by combining a soft GlowFilter (for a smooth dark perimeter)
	 * with a subtle DropShadowFilter (to give depth and contrast against the wooden planks).
	 */
	static inline function makeTitleShadow():Array<BitmapFilter> {
		return [
			new GlowFilter(0x000000, 0.65, 4.0, 4.0, 2.0, 2),
			new DropShadowFilter(3.0, 90.0, 0x000000, 0.6, 4.0, 4.0, 1.5, 2)
		];
	}

	static inline function makeBoldGoldShadow():Array<BitmapFilter> {
		return [
			new GlowFilter(0x000000, 0.65, 3.0, 3.0, 2.0, 2),
			new DropShadowFilter(2.0, 90.0, 0x000000, 0.6, 2.5, 2.5, 1.3, 2)
		];
	}

	static inline function makeDescriptionShadow():Array<BitmapFilter> {
		return [
			new GlowFilter(0x000000, 0.6, 2.5, 2.5, 1.6, 2),
			new DropShadowFilter(1.5, 90.0, 0x000000, 0.55, 2.0, 2.0, 1.0, 2)
		];
	}

	static inline function makeValueShadow():Array<BitmapFilter> {
		return [
			new GlowFilter(0x000000, 0.65, 3.0, 3.0, 2.0, 2),
			new DropShadowFilter(2.0, 90.0, 0x000000, 0.6, 2.5, 2.5, 1.3, 2)
		];
	}

	static inline final INJECTED_BASE_NAME = "drh_wood_base";
	static inline final INJECTED_BANNER_NAME = "drh_banner";

	var facade:DBFacade;
	var art:SettingsReskinArt;

	public function new(facade:DBFacade, art:SettingsReskinArt) {
		this.facade = facade;
		this.art = art;
	}

	/**
	 * Main reskin pipeline executed once when the Settings popup opens.
	 */
	public function reskin(clip:MovieClip, popup:Null<SettingsPopup>):Bool {
		if (clip == null || !art.townReady) return false;

		// 1. Hide the modern yellow/black hazard borders, dark background, and black grunge splats
		hideOriginalBackdrop(clip);

		// 2. Insert the authentic wooden plank board with metallic rivets behind all content
		injectWoodenBase(clip);

		// 3. Insert the red ribbon banner and center the "SETTINGS" title on it
		injectRedBannerAndTitle(clip);

		// 4. Style category tabs on the left panel (Graphics, Audio, Controls, etc.) with gold text
		if (popup != null) {
			styleCategoryTabs(@:privateAccess popup.mTabs);
		} else {
			styleCategoryTabsFromClip(clip);
		}

		// 5. Style the "RESET ALL SETTINGS" button with crisp white text
		if (popup != null) {
			styleResetButton(@:privateAccess popup.mResetButton);
		} else {
			styleResetButtonFromClip(clip);
		}

		// 6. Align the close "X" button precisely on the iron frame corner
		styleCloseButton(clip);

		// 7. Hook into setting rows so labels get styled automatically when switching categories
		if (popup != null) {
			hookSettingsList(popup);
		}

		return true;
	}

	/**
	 * Determines whether an instance name corresponds to a category tab panel (`panel_2`, `panel_3`, etc.).
	 * Uses simple string parsing instead of regex literals to ensure 100% compatibility with hxscript.
	 */
	static inline function isPanelTab(name:Null<String>):Bool {
		if (name == null || name == "panel_two_scroll_panel") return false;
		if (!StringTools.startsWith(name, "panel_")) return false;
		return Std.parseInt(name.substr(6)) != null;
	}

	/**
	 * Hides the post-1.0 hazard borders, dark background, and black grunge splats.
	 *
	 * Uses an explicit whitelist of functional component names (tab panels,
	 * scroll list, arrows, slider, reset button, and close button) plus a dynamic
	 * pattern check for category panels (`panel_2` through `panel_8` and beyond)
	 * to ensure we only hide background decorations without breaking any interactive UI.
	 */
	function hideOriginalBackdrop(clip:MovieClip):Void {
		var functionalNames:Map<String, Bool> = [
			"panel_two_scroll_panel" => true,
			"slider" => true,
			"uparrow" => true,
			"downarrow" => true,
			"leftarrow" => true,
			"rightarrow" => true,
			"title_label" => true,
			"reset_button" => true,
			"reset_label" => true,
			"Reset_Label" => true,
			"close" => true,
			"custom_settings_api_paging_bar" => true,
			INJECTED_BASE_NAME => true,
			INJECTED_BANNER_NAME => true
		];

		var i = clip.numChildren - 1;
		while (i >= 0) {
			var child = clip.getChildAt(i);
			if (child != null) {
				var name = child.name;
				if (name != null && (functionalNames.exists(name) || isPanelTab(name))) {
					// Functional or injected element: keep visible
				} else if (Std.isOfType(child, MovieClip) && (cast child : MovieClip).getChildByName("reset_label") != null) {
					// Reset button clip: keep visible
				} else {
					// Hide original hazard border, black splat, dark background
					child.visible = false;
				}
			}
			i--;
		}
	}

	/**
	 * Inserts the authentic wooden plank board (`popup_base`) from `db_UI_town.swf`
	 * at display index 0 (behind all interactive settings controls).
	 */
	function injectWoodenBase(clip:MovieClip):Void {
		if (clip.getChildByName(INJECTED_BASE_NAME) != null) return;

		var townPopup = art.popup();
		if (townPopup == null) return;

		var base = townPopup.getChildByName("popup_base");
		if (base != null) {
			base.name = INJECTED_BASE_NAME;
			base.scaleX = base.scaleY = 1.0;
			if (base.width > 0) base.scaleX = BASE_WIDTH / base.width;
			if (base.height > 0) base.scaleY = BASE_HEIGHT / base.height;
			base.x = BASE_CENTER_X;
			base.y = BASE_CENTER_Y;
			base.visible = true;
			clip.addChildAt(base, 0);
		}
	}

	/**
	 * Places the curved red ribbon banner behind the "SETTINGS" title
	 * and styles the title text with classic gold coloring and a soft comic shadow.
	 *
	 * Note: We intentionally preserve the game's default 1.0 font formatting and size,
	 * ensuring the text looks bold and natural without awkward artificial resizing.
	 */
	function injectRedBannerAndTitle(clip:MovieClip):Void {
		var banner = clip.getChildByName(INJECTED_BANNER_NAME);
		if (banner == null) {
			var rawBanner = art.banner();
			if (rawBanner != null) {
				banner = rawBanner;
				banner.name = INJECTED_BANNER_NAME;
				applyBannerScale(banner);

				var title:Null<DisplayObject> = clip.getChildByName("title_label");
				if (title != null) {
					var titleIdx = clip.getChildIndex(title);
					clip.addChildAt(banner, titleIdx);
				} else {
					clip.addChild(banner);
				}
			}
		} else {
			applyBannerScale(banner);
		}

		var titleTf:Null<TextField> = cast clip.getChildByName("title_label");
		if (titleTf != null) {
			titleTf.mouseEnabled = false;
			titleTf.wordWrap = false;
			titleTf.multiline = false;
			titleTf.textColor = GOLD_COLOR;
			titleTf.filters = makeTitleShadow();

			// Center the text while retaining the native font family and size
			var fmt = titleTf.defaultTextFormat;
			if (fmt == null) fmt = titleTf.getTextFormat();
			if (fmt != null) {
				fmt.align = TextFormatAlign.CENTER;
				titleTf.defaultTextFormat = fmt;
				titleTf.setTextFormat(fmt);
			}

			titleTf.width = BANNER_WIDTH;
			titleTf.height = TITLE_HEIGHT;
			titleTf.x = BANNER_X - BANNER_WIDTH / 2;
			titleTf.y = TITLE_Y;

			clip.addChild(titleTf); // Keep title on top of the banner
		}
	}

	/**
	 * Scales the red ribbon banner cleanly.
	 * Clears any conflicting nested 9-slice cuts so Flash's original vector authoring
	 * handles horizontal stretching smoothly without distorting the curly ribbon ends.
	 */
	function applyBannerScale(banner:DisplayObject):Void {
		if (Std.isOfType(banner, DisplayObjectContainer)) {
			var doc:DisplayObjectContainer = cast banner;
			for (i in 0...doc.numChildren) {
				var child = doc.getChildAt(i);
				if (child != null) {
					child.scale9Grid = null;
				}
			}
		}

		banner.scaleX = banner.scaleY = 1.0;
		if (banner.width > 0) banner.scaleX = BANNER_WIDTH / banner.width;
		if (banner.height > 0) banner.scaleY = BANNER_HEIGHT / banner.height;
		banner.x = BANNER_X;
		banner.y = BANNER_Y;
		banner.visible = true;
	}

	/**
	 * Positions the close button ("X") so its center sits directly on the
	 * intersection of the top horizontal iron bar and right vertical iron bar,
	 * and brings it to the top display layer for responsive clicking.
	 */
	function styleCloseButton(clip:MovieClip):Void {
		var closeBtn:Null<DisplayObject> = clip.getChildByName("close");
		if (closeBtn != null) {
			closeBtn.x = CLOSE_X;
			closeBtn.y = CLOSE_Y;
			closeBtn.visible = true;
			clip.addChild(closeBtn);
		}
	}

	/**
	 * Applies gold color and soft shadows to the category tabs on the left panel.
	 */
	function styleCategoryTabs(tabs:Null<SettingsCategoryTabs>):Void {
		if (tabs == null) return;
		for (btn in tabs.buttons) {
			if (btn == null || btn.root == null) continue;
			stylePanelLabels(btn.root);
		}
	}

	function styleCategoryTabsFromClip(clip:MovieClip):Void {
		var i = 0;
		while (i < clip.numChildren) {
			var child = clip.getChildAt(i);
			if (child != null && isPanelTab(child.name) && Std.isOfType(child, DisplayObjectContainer)) {
				stylePanelLabels(cast child);
			}
			i++;
		}
	}

	function stylePanelLabels(container:DisplayObjectContainer):Void {
		var i = 0;
		while (i < container.numChildren) {
			var child = container.getChildAt(i);
			if (child != null) {
				if (Std.isOfType(child, TextField)) {
					var tf:TextField = cast child;
					tf.textColor = GOLD_COLOR;
					var fmt = tf.defaultTextFormat;
					if (fmt != null) {
						fmt.color = GOLD_COLOR;
						tf.defaultTextFormat = fmt;
						tf.setTextFormat(fmt);
					}
					tf.filters = makeBoldGoldShadow();
				} else if (Std.isOfType(child, DisplayObjectContainer)) {
					stylePanelLabels(cast child);
				}
			}
			i++;
		}
	}

	/**
	 * Styles the "RESET ALL SETTINGS" button with crisp white text and a soft shadow.
	 */
	function styleResetButton(resetBtn:Null<UIButton>):Void {
		if (resetBtn == null || resetBtn.root == null) return;
		styleResetClip(resetBtn.root);
	}

	function styleResetButtonFromClip(clip:MovieClip):Void {
		var i = 0;
		while (i < clip.numChildren) {
			var child = clip.getChildAt(i);
			if (child != null && Std.isOfType(child, MovieClip)) {
				var mc:MovieClip = cast child;
				if (mc.getChildByName("reset_label") != null || mc.name == "reset_button") {
					styleResetClip(mc);
					return;
				}
			}
			i++;
		}
	}

	function styleResetClip(rClip:MovieClip):Void {
		var label:Null<TextField> = cast rClip.getChildByName("reset_label");
		if (label != null) {
			label.textColor = WHITE_COLOR;
			label.filters = makeValueShadow();
		}
	}

	/**
	 * Hooks into the SettingsPopup so that whenever a category is displayed or switched,
	 * the setting rows are styled with gold titles, warm tan descriptions, and soft shadows.
	 */
	function hookSettingsList(popup:SettingsPopup):Void {
		var list:Null<SettingsList> = @:privateAccess popup.mList;
		var tabs:Null<SettingsCategoryTabs> = @:privateAccess popup.mTabs;
		if (list == null) return;

		var styleAllRows = function() {
			var rows:Dynamic = @:privateAccess list.mRows;
			if (rows == null) return;
			for (row in rows) {
				styleRow(row);
			}
		};

		// Style whichever category is currently displayed
		styleAllRows();

		// Safely wrap the tabs selection callback so switching tabs styles the new rows
		if (tabs != null) {
			var origCallback = @:privateAccess tabs.mSelectionCallback;
			@:privateAccess tabs.mSelectionCallback = function(category:String) {
				if (origCallback != null) {
					origCallback(category);
				}
				styleAllRows();
			};
		}
	}

	/**
	 * Styles an individual setting row:
	 * - Option title: bold gold with soft shadow
	 * - Option description: warm parchment tan with subtle shadow
	 * - Value text (if present): crisp white with shadow
	 * - Row background stripe: lowered opacity so the underlying wood grain remains visible
	 */
	function styleRow(row:SettingRow):Void {
		if (row == null || row.root == null) return;

		// 1. Setting name (gold bold with soft drop shadow)
		var nameLabel:Null<TextField> = @:privateAccess row.mNameLabel;
		if (nameLabel != null) {
			nameLabel.textColor = GOLD_COLOR;
			nameLabel.filters = makeBoldGoldShadow();
		}

		// 2. Setting description (warm parchment tan with soft shadow)
		var descLabel:Null<TextField> = @:privateAccess row.mDescriptionLabel;
		if (descLabel != null) {
			descLabel.textColor = TAN_COLOR;
			descLabel.filters = makeDescriptionShadow();
		}

		// 3. Current value label if present (crisp white with shadow)
		var valLabel:Null<TextField> = @:privateAccess row.mValueLabel;
		if (valLabel != null) {
			valLabel.textColor = WHITE_COLOR;
			valLabel.filters = makeValueShadow();
		}

		// 4. Subtle zebra striping: reduce opacity so the wood texture shows through
		var r1 = row.root.getChildByName("dark_row_1");
		if (r1 != null) r1.alpha = 0.3;
		var r2 = row.root.getChildByName("dark_row_2");
		if (r2 != null) r2.alpha = 0.3;

		// 5. Ensure any additional row text (e.g. keybind prompts) also receives clean shadows
		styleRemainingRowTextFields(row.root, nameLabel, descLabel, valLabel);
	}

	function styleRemainingRowTextFields(container:DisplayObjectContainer, known1:Null<TextField>, known2:Null<TextField>, known3:Null<TextField>):Void {
		var i = 0;
		while (i < container.numChildren) {
			var child = container.getChildAt(i);
			if (child != null) {
				if (Std.isOfType(child, TextField)) {
					var tf:TextField = cast child;
					if (tf != known1 && tf != known2 && tf != known3) {
						tf.filters = makeDescriptionShadow();
					}
				} else if (Std.isOfType(child, DisplayObjectContainer)) {
					styleRemainingRowTextFields(cast child, known1, known2, known3);
				}
			}
			i++;
		}
	}

	public function styleAllVisibleRows(popup:SettingsPopup):Void {
		if (popup == null) return;
		var list:Null<SettingsList> = @:privateAccess popup.mList;
		if (list == null) return;
		var rows:Dynamic = @:privateAccess list.mRows;
		if (rows == null) return;
		for (row in rows) {
			styleRow(row);
		}
	}

	public function ensureColors(popup:Null<SettingsPopup>, clip:Null<MovieClip>):Void {
		if (clip != null) {
			styleCategoryTabsFromClip(clip);
			styleResetButtonFromClip(clip);
		}
		if (popup != null) {
			var list:Null<SettingsList> = @:privateAccess popup.mList;
			if (list != null) {
				var rows:Dynamic = @:privateAccess list.mRows;
				if (rows != null && rows.length > 0) {
					var firstRow:Dynamic = rows[0];
					var nameLabel:Null<TextField> = (firstRow != null) ? @:privateAccess firstRow.mNameLabel : null;
					if (nameLabel != null && nameLabel.textColor != GOLD_COLOR) {
						styleAllVisibleRows(popup);
					}
				}
			}
		}
	}

	public function destroy():Void {
		facade = null;
		art = null;
	}
}
