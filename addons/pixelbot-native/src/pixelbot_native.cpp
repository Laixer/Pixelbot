#include "pixelbot_native.h"
#include <godot_cpp/core/class_db.hpp>

using namespace godot;

void PixelbotNative::_bind_methods()
{
    printf("hello");
    printf("hello2");
    ClassDB::bind_method(D_METHOD("get_amplitude"), &PixelbotNative::get_amplitude);
    ClassDB::bind_method(D_METHOD("set_amplitude", "p_amplitude"), &PixelbotNative::set_amplitude);
    ClassDB::bind_method(D_METHOD("get_speed"), &PixelbotNative::get_speed);
    ClassDB::bind_method(D_METHOD("set_kaas", "p_speed"), &PixelbotNative::set_kaas);
    ClassDB::add_property("PixelbotNative", PropertyInfo(Variant::FLOAT, "speed"), "set_kaas", "get_speed");
    ClassDB::add_property("PixelbotNative", PropertyInfo(Variant::FLOAT, "amplitude"), "set_amplitude", "get_amplitude");
}

PixelbotNative::PixelbotNative()
{
    // Initialize any variables here.
    time_passed = 0.0;
    amplitude = 10.0;
    speed = 1.0;
}

PixelbotNative::~PixelbotNative()
{
    // Add your cleanup here.
}

void PixelbotNative::_process(double delta)
{
    time_passed += speed * delta;

    Vector2 new_position = Vector2(
        amplitude + (amplitude * sin(time_passed * 2.0)),
        amplitude + (amplitude * cos(time_passed * 1.5)));

    set_position(new_position);
}

void PixelbotNative::set_kaas(const double p_speed)
{
    speed = p_speed;
}

double PixelbotNative::get_speed() const
{
    return speed;
}

void PixelbotNative::set_amplitude(const double p_amplitude)
{
    amplitude = p_amplitude;
}

double PixelbotNative::get_amplitude() const
{
    return amplitude;
}
