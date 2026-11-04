using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;
using StickDrift.Car;

namespace StickDrift.UI
{
    /// <summary>
    /// Builds the landscape touch layout in code:
    /// steering wheel bottom-left, H-pattern shifter + e-brake lever bottom-right, HUD up top.
    /// Controls are semi-transparent white so the night scene shows through.
    /// </summary>
    public static class UIBuilder
    {
        static readonly Color Ghost = new Color(1f, 1f, 1f, 0.38f);
        static readonly Color GhostStrong = new Color(1f, 1f, 1f, 0.55f);
        static readonly Color GhostFaint = new Color(1f, 1f, 1f, 0.16f);
        static readonly Color Accent = new Color(1f, 0.55f, 0.15f, 0.85f);

        static Font font;

        /// <returns>The full-screen RawImage the pixelated world gets drawn into.</returns>
        public static RawImage Build(CarControls controls, DriftCar car)
        {
            font = Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");

            var es = new GameObject("EventSystem", typeof(EventSystem), typeof(StandaloneInputModule));
            es.GetComponent<EventSystem>().pixelDragThreshold = 2;

            var canvasGo = new GameObject("UI", typeof(Canvas), typeof(CanvasScaler), typeof(GraphicRaycaster));
            var canvas = canvasGo.GetComponent<Canvas>();
            canvas.renderMode = RenderMode.ScreenSpaceOverlay;
            var scaler = canvasGo.GetComponent<CanvasScaler>();
            scaler.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
            scaler.referenceResolution = new Vector2(1920f, 1080f);
            scaler.screenMatchMode = CanvasScaler.ScreenMatchMode.MatchWidthOrHeight;
            scaler.matchWidthOrHeight = 1f;
            var root = (RectTransform)canvasGo.transform;

            var world = NewRect("World", root);
            Stretch(world);
            var raw = world.gameObject.AddComponent<RawImage>();
            raw.raycastTarget = false;

            var safe = NewRect("Safe Area", root);
            Stretch(safe);
            safe.gameObject.AddComponent<SafeArea>();

            BuildWheel(safe, controls);
            controls.shifter = BuildShifter(safe, controls);
            BuildHandbrake(safe, controls);
            BuildHud(safe, car);

            return raw;
        }

        // ------------------------------------------------------------------ controls

        static void BuildWheel(RectTransform parent, CarControls controls)
        {
            var area = NewRect("Steering Wheel", parent);
            Anchor(area, new Vector2(0f, 0f), new Vector2(310f, 300f), new Vector2(480f, 480f));
            area.gameObject.AddComponent<Image>().color = Color.clear; // touch target

            var wheel = NewRect("Wheel", area);
            Anchor(wheel, new Vector2(0.5f, 0.5f), Vector2.zero, new Vector2(440f, 440f));

            Img(wheel, "Rim", ShapeSprites.Ring, Ghost, Vector2.zero, new Vector2(440f, 440f));
            foreach (float a in new[] { 0f, 180f, 270f })
            {
                var spoke = NewRect("Spoke", wheel);
                spoke.anchorMin = spoke.anchorMax = new Vector2(0.5f, 0.5f);
                spoke.pivot = new Vector2(0f, 0.5f);
                spoke.anchoredPosition = Vector2.zero;
                spoke.sizeDelta = new Vector2(190f, 30f);
                spoke.localEulerAngles = new Vector3(0f, 0f, a);
                var img = spoke.gameObject.AddComponent<Image>();
                img.color = GhostFaint;
                img.raycastTarget = false;
            }
            Img(wheel, "Hub", ShapeSprites.Circle, GhostFaint, Vector2.zero, new Vector2(110f, 110f));
            Img(wheel, "Top Marker", null, Accent, new Vector2(0f, 202f), new Vector2(22f, 38f));

            var sw = area.gameObject.AddComponent<SteeringWheelUI>();
            sw.controls = controls;
            sw.wheel = wheel;
        }

        static ShifterUI BuildShifter(RectTransform parent, CarControls controls)
        {
            const float unit = 120f;
            var area = NewRect("Shifter", parent);
            Anchor(area, new Vector2(1f, 0f), new Vector2(-560f, 300f), new Vector2(420f, 420f));
            area.gameObject.AddComponent<Image>().color = new Color(1f, 1f, 1f, 0.05f);

            // Gate
            Img(area, "Neutral Row", null, GhostFaint, Vector2.zero, new Vector2(2f * unit + 16f, 16f));
            for (int c = -1; c <= 1; c++)
                Img(area, "Column", null, GhostFaint, new Vector2(c * unit, 0f), new Vector2(16f, 2f * unit + 16f));

            foreach (int g in new[] { 1, 2, 3, 4, 5, Gearbox.Reverse })
            {
                Vector2 slot = ShifterUI.SlotFor(g);
                var label = Txt(area, "Label " + g, Gearbox.Label(g), 34, TextAnchor.MiddleCenter, Ghost);
                Anchor(label.rectTransform, new Vector2(0.5f, 0.5f), slot * unit + new Vector2(0f, Mathf.Sign(slot.y) * 52f), new Vector2(60f, 50f));
            }

            var knob = NewRect("Knob", area);
            Anchor(knob, new Vector2(0.5f, 0.5f), Vector2.zero, new Vector2(118f, 118f));
            var knobImg = knob.gameObject.AddComponent<Image>();
            knobImg.sprite = ShapeSprites.Circle;
            knobImg.color = GhostStrong;
            knobImg.raycastTarget = false;
            Img(knob, "Knob Ring", ShapeSprites.ThinRing, Accent, Vector2.zero, new Vector2(84f, 84f));

            var shifter = area.gameObject.AddComponent<ShifterUI>();
            shifter.controls = controls;
            shifter.knob = knob;
            shifter.unit = unit;
            return shifter;
        }

        static void BuildHandbrake(RectTransform parent, CarControls controls)
        {
            var area = NewRect("E-Brake", parent);
            Anchor(area, new Vector2(1f, 0f), new Vector2(-190f, 330f), new Vector2(170f, 470f));
            area.gameObject.AddComponent<Image>().color = Color.clear;

            Img(area, "Track", null, GhostFaint, Vector2.zero, new Vector2(18f, 400f));

            var handle = NewRect("Handle", area);
            Anchor(handle, new Vector2(0.5f, 0.5f), new Vector2(0f, 140f), new Vector2(130f, 80f));
            var hImg = handle.gameObject.AddComponent<Image>();
            hImg.color = GhostStrong;
            hImg.raycastTarget = false;
            var t = Txt(handle, "Label", "E-BRAKE", 24, TextAnchor.MiddleCenter, new Color(0f, 0f, 0f, 0.7f));
            Stretch(t.rectTransform);

            var hb = area.gameObject.AddComponent<HandbrakeUI>();
            hb.controls = controls;
            hb.handle = handle;
            hb.topY = 140f;
            hb.travel = 260f;
        }

        // ------------------------------------------------------------------ HUD

        static void BuildHud(RectTransform parent, DriftCar car)
        {
            var hudRoot = NewRect("HUD", parent);
            Stretch(hudRoot);
            var hud = hudRoot.gameObject.AddComponent<HudUI>();
            hud.car = car;

            var top = new Vector2(0.5f, 1f);
            hud.gearText = Txt(hudRoot, "Gear", "N", 120, TextAnchor.MiddleCenter, new Color(1f, 1f, 1f, 0.92f));
            hud.gearText.fontStyle = FontStyle.Bold;
            Anchor(hud.gearText.rectTransform, top, new Vector2(0f, -90f), new Vector2(220f, 150f));

            hud.speedText = Txt(hudRoot, "Speed", "0 MPH", 40, TextAnchor.MiddleRight, Ghost * 2f);
            Anchor(hud.speedText.rectTransform, top, new Vector2(-270f, -100f), new Vector2(280f, 60f));

            hud.bestText = Txt(hudRoot, "Best", "", 36, TextAnchor.MiddleLeft, Ghost * 2f);
            Anchor(hud.bestText.rectTransform, top, new Vector2(270f, -100f), new Vector2(280f, 60f));

            // Tach
            hud.tachWidth = 640f;
            var tach = NewRect("Tach", hudRoot);
            Anchor(tach, top, new Vector2(0f, -185f), new Vector2(hud.tachWidth, 22f));
            tach.gameObject.AddComponent<Image>().color = new Color(0f, 0f, 0f, 0.35f);

            float redStart = hud.tachWidth * car.engine.redlineRpm / hud.tachMaxRpm;
            var zone = NewRect("Redline Zone", tach);
            LeftBar(zone, redStart, 22f);
            zone.gameObject.AddComponent<Image>().color = new Color(1f, 0.15f, 0.1f, 0.35f);

            hud.tachFill = NewRect("Tach Fill", tach);
            LeftBar(hud.tachFill, 0f, 22f);
            hud.tachFillImage = hud.tachFill.gameObject.AddComponent<Image>();

            // Engine health
            var engLabel = Txt(hudRoot, "Engine Label", "ENGINE", 24, TextAnchor.MiddleLeft, Ghost * 2f);
            Anchor(engLabel.rectTransform, new Vector2(0f, 1f), new Vector2(130f, -40f), new Vector2(220f, 30f));
            hud.healthWidth = 220f;
            var health = NewRect("Health", hudRoot);
            Anchor(health, new Vector2(0f, 1f), new Vector2(130f, -70f), new Vector2(hud.healthWidth, 12f));
            health.gameObject.AddComponent<Image>().color = new Color(0f, 0f, 0f, 0.35f);
            hud.healthFill = NewRect("Health Fill", health);
            LeftBar(hud.healthFill, 0f, 12f);
            hud.healthFill.sizeDelta = new Vector2(hud.healthWidth, 12f);
            hud.healthFill.gameObject.AddComponent<Image>().color = new Color(0.55f, 1f, 0.6f, 0.8f);

            hud.warnText = Txt(hudRoot, "Warning", "", 80, TextAnchor.MiddleCenter, new Color(1f, 0.3f, 0.25f, 0.95f));
            hud.warnText.fontStyle = FontStyle.Bold;
            Anchor(hud.warnText.rectTransform, new Vector2(0.5f, 0.5f), new Vector2(0f, 170f), new Vector2(900f, 120f));

            hud.driftText = Txt(hudRoot, "Drift", "", 56, TextAnchor.MiddleCenter, new Color(1f, 1f, 1f, 0.9f));
            hud.driftText.fontStyle = FontStyle.Bold;
            Anchor(hud.driftText.rectTransform, new Vector2(0.5f, 1f), new Vector2(0f, -290f), new Vector2(700f, 140f));

            MakeButton(hudRoot, "Reset", "RESET", new Vector2(1f, 1f), new Vector2(-120f, -60f), new Vector2(170f, 64f), car.ResetToSpawn);

            // Blown engine screen
            var panel = NewRect("Engine Blown", hudRoot);
            Anchor(panel, new Vector2(0.5f, 0.5f), new Vector2(0f, 20f), new Vector2(900f, 380f));
            panel.gameObject.AddComponent<Image>().color = new Color(0f, 0f, 0f, 0.72f);
            var title = Txt(panel, "Title", "ENGINE BLOWN", 92, TextAnchor.MiddleCenter, new Color(1f, 0.3f, 0.25f, 1f));
            title.fontStyle = FontStyle.Bold;
            Anchor(title.rectTransform, new Vector2(0.5f, 0.5f), new Vector2(0f, 95f), new Vector2(880f, 120f));
            var sub = Txt(panel, "Sub", "should've shifted", 36, TextAnchor.MiddleCenter, Ghost * 2f);
            Anchor(sub.rectTransform, new Vector2(0.5f, 0.5f), new Vector2(0f, 15f), new Vector2(880f, 50f));
            MakeButton(panel, "New Engine", "NEW ENGINE", new Vector2(0.5f, 0.5f), new Vector2(0f, -100f), new Vector2(360f, 90f), car.RepairEngine);
            hud.blownPanel = panel.gameObject;
            panel.gameObject.SetActive(false);
        }

        // ------------------------------------------------------------------ helpers

        static RectTransform NewRect(string name, Transform parent)
        {
            var go = new GameObject(name, typeof(RectTransform));
            go.transform.SetParent(parent, false);
            return (RectTransform)go.transform;
        }

        static void Stretch(RectTransform rt)
        {
            rt.anchorMin = Vector2.zero;
            rt.anchorMax = Vector2.one;
            rt.offsetMin = rt.offsetMax = Vector2.zero;
        }

        static void Anchor(RectTransform rt, Vector2 anchor, Vector2 pos, Vector2 size)
        {
            rt.anchorMin = rt.anchorMax = anchor;
            rt.pivot = new Vector2(0.5f, 0.5f);
            rt.anchoredPosition = pos;
            rt.sizeDelta = size;
        }

        /// <summary>A bar that grows to the right from the parent's left edge.</summary>
        static void LeftBar(RectTransform rt, float x, float height)
        {
            rt.anchorMin = rt.anchorMax = new Vector2(0f, 0.5f);
            rt.pivot = new Vector2(0f, 0.5f);
            rt.anchoredPosition = new Vector2(x, 0f);
            rt.sizeDelta = new Vector2(0f, height);
            if (x > 0f)
            {
                var parent = (RectTransform)rt.parent;
                rt.sizeDelta = new Vector2(parent.sizeDelta.x - x, height);
            }
        }

        static Image Img(RectTransform parent, string name, Sprite sprite, Color color, Vector2 pos, Vector2 size)
        {
            var rt = NewRect(name, parent);
            Anchor(rt, new Vector2(0.5f, 0.5f), pos, size);
            var img = rt.gameObject.AddComponent<Image>();
            img.sprite = sprite;
            img.color = color;
            img.raycastTarget = false;
            return img;
        }

        static Text Txt(RectTransform parent, string name, string text, int size, TextAnchor align, Color color)
        {
            var rt = NewRect(name, parent);
            var t = rt.gameObject.AddComponent<Text>();
            t.font = font;
            t.text = text;
            t.fontSize = size;
            t.alignment = align;
            t.color = color;
            t.raycastTarget = false;
            t.horizontalOverflow = HorizontalWrapMode.Overflow;
            t.verticalOverflow = VerticalWrapMode.Overflow;
            return t;
        }

        static void MakeButton(RectTransform parent, string name, string label, Vector2 anchor, Vector2 pos, Vector2 size, UnityEngine.Events.UnityAction onClick)
        {
            var rt = NewRect(name, parent);
            Anchor(rt, anchor, pos, size);
            var img = rt.gameObject.AddComponent<Image>();
            img.color = new Color(1f, 1f, 1f, 0.2f);
            var b = rt.gameObject.AddComponent<Button>();
            b.targetGraphic = img;
            b.onClick.AddListener(onClick);
            var t = Txt(rt, "Label", label, 30, TextAnchor.MiddleCenter, Color.white);
            Stretch(t.rectTransform);
        }
    }
}
