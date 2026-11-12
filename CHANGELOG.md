# Gram Frames changelog

## 2.2.5
- Colors, font and bar texture moved to the **General** page. Set them once and they're used by party and raid frames. Your party frame colors carry over.
- My Target Color and My Target Thickness are on the General page too.

## 2.2.4
- The box around the person you have targeted is gold now instead of white. Pick any color and thickness under My Target Color / My Target Thickness.
- Aggro is always bright red: the border and the AGGRO / LOSING / YOU label.
- **AFK** shows on the frame with a minute timer (AFK 3m). **OFFLINE** shows its minutes too (OFFLINE 12m). Turn AFK off under Icons → Show AFK.
- More color pickers: Name Color → Pick a color, Health Text Color, and Border Color.

## 2.2.3
- New screenshots and CurseForge art showing the current look.
- Cleaned up the Role Icon Style labels.

## 2.2.2
- Role icons use Blizzard's round set (shield, cross, sword in a gold ring). The small set is still under Icons → Role Icon Style.
- Healer gradient color stays right for out-of-range players.

## 2.2.1
- Dark mode matches EllesmereUI: dark health over light-grey missing health. With **Match EllesmereUI** on, both colors come straight from EllesmereUI's dark mode.
- New **Health Color** and **Missing Health Color** pickers (turn off Match EllesmereUI to use your own).
- **DRINKING** shows on a frame while that player eats or drinks (Icons → Show Drinking).
- Out of range is a plain fade again, with real health kept. The grey-out box is still an option under Out of Range.

## 2.2.0
- New **Out of Range** section: fade the frame or grey out the whole box, with color and dimming options.
- Raid markers sit inside the frame (so the frame above can't cover them), with a **Raid Marker Size** slider.
- New click-casting action: **Raid Marker**. Bind a click to put a marker on someone (click again to take it off).

## 2.1.8
- Health bars use health percent, which stays right for groupmates at any distance. Fixes far-away players showing an all-red bar.

## 2.1.7
- Health keeps updating for out-of-range players.
- DPS role icons show for everyone (Icons → Hide DPS Icon to turn them off).

## 2.1.6
- `/gf debug` prints what the game reports for each frame (handy for bug reports).

## 2.1.5
- Range fading fixed: far-away players fade, players in another phase fade, offline players get a steady dim look.

## 2.1.4
- **Bar Texture** picker: Blizzard textures, anything shared through LibSharedMedia, and EllesmereUI's textures if you run it.
- **Match EllesmereUI** takes the dark-mode colors from EllesmereUI.
- Texture and color changes apply instantly, even in combat.

## 2.1.3
- Groupmates the game can't see no longer show an all-red bar.

## 2.1.2
- Party frames show your 4 groupmates, not you (Party Frames → Show Me to add yourself).

## 2.1.1
- New wording: Gram Frames is described as its own creation, with a thank-you to the frame addons that inspired it.

## 2.1.0
- Party Frames and Raid Frames are separate tabs, each with its own spot on screen, size, colors, buffs and debuffs. 10, 20 and 40-man each get their own setup.
- Tank panel has its own spot for party and for raid.
- Pick your own bar and background colors in any mode.
- Click-casting: class spell list with icons and a separate Rank dropdown for downranking.
- Healer Mana built in.
- Debuffs use Forever's built-in aura display, so they keep working in dungeons and combat.
- Hide When Solo, Hide Frame Bar, role icon size, rounded switches.
