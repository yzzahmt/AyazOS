// AyazOS pencere efektleri (Wayfire 0.10 animate eklentisine kayıtlı).
//
//   dock   : küçültmede pencere sağdaki dock'a doğru süzülerek küçülür,
//            geri yüklemede aynı yoldan geri gelir.
//   rise   : açılışta pencere hafifçe aşağıdan yükselir ve belirir.
//
// Yalnızca 2B dönüştürücü kullanır; GLES, Vulkan ve Pixman'da çalışır.

#include <cmath>
#include <wayfire/core.hpp>
#include <wayfire/output.hpp>
#include <wayfire/plugin.hpp>
#include <wayfire/view.hpp>
#include <wayfire/toplevel-view.hpp>
#include <wayfire/view-transform.hpp>
#include <wayfire/option-wrapper.hpp>
#include <wayfire/util/duration.hpp>
#include <wayfire/plugins/animate/animate.hpp>
#include <wayfire/plugins/common/shared-core-data.hpp>

namespace ayaz
{
static wf::option_wrapper_t<wf::animation_description_t> dock_duration{"ayaz-effects/dock_duration"};
static wf::option_wrapper_t<wf::animation_description_t> rise_duration{"ayaz-effects/rise_duration"};
static wf::option_wrapper_t<int> dock_margin{"ayaz-effects/dock_margin"};

static float lerp(float a, float b, float t) { return a + (b - a) * t; }

class base_effect : public wf::animate::animation_base_t
{
  protected:
    wayfire_view view;
    std::shared_ptr<wf::scene::view_2d_transformer_t> tr;
    std::unique_ptr<wf::animation::simple_animation_t> progress;
    bool hiding = false;
    std::string name;

    virtual void apply(float p) = 0;

  public:
    void init(wayfire_view v, wf::animation_description_t dur, wf::animate::animation_type type) override
    {
        view   = v;
        hiding = type & WF_ANIMATE_HIDING_ANIMATION;
        progress = std::make_unique<wf::animation::simple_animation_t>(wf::create_option(dur));
        tr = std::make_shared<wf::scene::view_2d_transformer_t>(view);
        view->get_transformed_node()->add_transformer(tr, wf::TRANSFORMER_HIGHLEVEL, name);
        if (hiding)
            progress->animate(0, 1);
        else
            progress->animate(1, 0);
        apply((float)(double)*progress);
    }

    bool step() override
    {
        if (!view || !tr)
            return false;

        auto node = view->get_transformed_node();
        node->begin_transform_update();
        apply((float)(double)*progress);
        node->end_transform_update();

        if (!progress->running())
        {
            node->rem_transformer(name);
            tr = nullptr;
            return false;
        }

        return true;
    }

    void reverse() override
    {
        double now = *progress;
        hiding = !hiding;
        progress->animate(now, hiding ? 1 : 0);
    }

    ~base_effect() override
    {
        if (view && tr)
            view->get_transformed_node()->rem_transformer(name);
    }
};

// Küçültme: önce yerinde biraz büzülür, sonra yatayda incelerek dock'a akar.
class dock_effect : public base_effect
{
  public:
    dock_effect() { name = "ayaz-dock"; }

  protected:
    void apply(float p) override
    {
        auto bbox = view->get_bounding_box();
        float cx = bbox.x + bbox.width / 2.0f;
        float cy = bbox.y + bbox.height / 2.0f;

        // Hedef: istemcinin bildirdiği simge kutusu, yoksa çıkışın sağ ortası (dock).
        float tx = cx, ty = cy;
        auto toplevel = wf::toplevel_cast(view);
        wlr_box hint = toplevel ? toplevel->get_minimize_hint() : wlr_box{0, 0, 0, 0};
        if (hint.width > 0 && hint.height > 0)
        {
            tx = hint.x + hint.width / 2.0f;
            ty = hint.y + hint.height / 2.0f;
        } else if (auto out = view->get_output())
        {
            auto g = out->get_layout_geometry();
            tx = g.x + g.width - (int)dock_margin;
            ty = g.y + g.height / 2.0f;
        }

        float move = std::pow(p, 1.35f);
        float sx = lerp(1.0f, 0.03f, std::pow(p, 0.85f));
        float sy = lerp(1.0f, 0.08f, std::pow(p, 1.10f));
        tr->scale_x = sx;
        tr->scale_y = sy;
        tr->translation_x = (tx - cx) * move;
        tr->translation_y = (ty - cy) * move;
        tr->alpha = 1.0f - std::pow(p, 2.6f);
    }
};

// Açılış: %94 boyuttan ve 18 px aşağıdan yükselerek belirir.
class rise_effect : public base_effect
{
  public:
    rise_effect() { name = "ayaz-rise"; }

  protected:
    void apply(float p) override
    {
        float s = lerp(1.0f, 0.94f, p);
        tr->scale_x = s;
        tr->scale_y = s;
        tr->translation_y = 18.0f * p;
        tr->alpha = 1.0f - p;
    }
};
}

class ayaz_effects_plugin : public wf::plugin_interface_t
{
    wf::shared_data::ref_ptr_t<wf::animate::animate_effects_registry_t> registry;

  public:
    void init() override
    {
        registry->register_effect("dock", wf::animate::effect_description_t{
            .generator = [] { return std::make_unique<ayaz::dock_effect>(); },
            .default_duration = [] { return ayaz::dock_duration.value(); },
        });
        registry->register_effect("rise", wf::animate::effect_description_t{
            .generator = [] { return std::make_unique<ayaz::rise_effect>(); },
            .default_duration = [] { return ayaz::rise_duration.value(); },
        });
    }

    void fini() override
    {
        registry->unregister_effect("dock");
        registry->unregister_effect("rise");
    }
};

DECLARE_WAYFIRE_PLUGIN(ayaz_effects_plugin);
