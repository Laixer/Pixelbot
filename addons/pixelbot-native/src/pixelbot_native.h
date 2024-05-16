#ifndef PIXELBOT_NATIVE_H
#define PIXELBOT_NATIVE_H

#include <godot_cpp/classes/sprite2d.hpp>

namespace godot
{

    class PixelbotNative : public Sprite2D
    {
        GDCLASS(PixelbotNative, Sprite2D)

    private:
        double time_passed;
        double amplitude;
        double speed;

    protected:
        static void _bind_methods();

    public:
        PixelbotNative();
        ~PixelbotNative();

        void _process(double delta) override;
        void set_amplitude(const double p_amplitude);
        double get_amplitude() const;
        void set_kaas(const double p_speed);
        double get_speed() const;
    };

}

#endif