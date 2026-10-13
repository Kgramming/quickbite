"""Seed v1 data: users, restaurants, menus. Idempotent — safe to re-run.

Usage:  python -m app.v1.seed
"""

from sqlalchemy import select

from app.database import SessionLocal, init_db
from app.v1.auth import hash_password
from app.v1.models import MenuItem, Restaurant, User

CUSTOMER_EMAIL = "customer@example.com"
ADMIN_EMAIL = "admin@example.com"

RESTAURANTS = [
    {
        "id": "rest_biryani",
        "name": "Biryani Blues",
        "description": "Dum biryanis and kebabs",
        "items": [
            ("item_chicken_biryani", "Chicken Dum Biryani", "Fragrant basmati, saffron, mirchi ka salan", 24999),
            ("item_veg_biryani", "Veg Dum Biryani", "Seasonal vegetables, fried onions", 19999),
            ("item_kebab_platter", "Kebab Platter", "Chicken tikka, seekh kebab, tangdi", 34999),
            ("item_raita", "Burhani Raita", "Garlic-mint raita", 4999),
            ("item_mutton_biryani", "Mutton Dum Biryani", "Tender mutton, kewra water", 34999),
            ("item_egg_biryani", "Egg Biryani", "Masala fried eggs, fragrant rice", 17999),
            ("item_chicken_tikka", "Chicken Tikka (6 pc)", "Char-grilled, mint chutney", 24999),
            ("item_seekh_kebab", "Seekh Kebab (4 pc)", "Hand-pressed, saffron aioli", 27999),
            ("item_gulab_jamun", "Gulab Jamun (4 pc)", "Warm, syrup-soaked", 9999),
            ("item_double_ka_meetha", "Double ka Meetha", "Hyderabadi bread pudding", 12999),
        ],
    },
    {
        "id": "rest_pizza",
        "name": "Slice Society",
        "description": "Wood-fired pizzas",
        "items": [
            ("item_margherita", "Margherita", "San Marzano tomato, fior di latte, basil", 29999),
            ("item_paneer_tikka_pizza", "Paneer Tikka Pizza", "Smoky paneer, onions, mint drizzle", 34999),
            ("item_garlic_bread", "Garlic Breadsticks", "With marinara dip", 14999),
            ("item_pepperoni", "Pepperoni Blast", "Double pepperoni, mozzarella", 39999),
            ("item_veggie_supreme", "Veggie Supreme", "Bell peppers, mushrooms, olives", 32999),
            ("item_bbq_chicken", "BBQ Chicken Pizza", "Smoky BBQ sauce, grilled chicken", 39999),
            ("item_four_cheese", "Quattro Formaggi", "Four cheeses blend", 42999),
            ("item_tiramisu", "Tiramisu", "Espresso-soaked, mascarpone", 19999),
            ("item_choco_lava", "Choco Lava Cake", "Molten center", 14999),
            ("item_cheesy_dip", "Cheesy Jalapeno Dip", "Creamy, spicy", 12999),
        ],
    },
    {
        "id": "rest_dosa",
        "name": "Dosa District",
        "description": "South Indian classics",
        "items": [
            ("item_masala_dosa", "Masala Dosa", "Crisp crepe, potato palya, trio of chutneys", 12999),
            ("item_idli_sambar", "Idli Sambar (4 pc)", "Soft idlis, drumstick sambar", 8999),
            ("item_filter_coffee", "Filter Coffee", "Degree coffee, frothed milk", 5999),
            ("item_medu_vada", "Medu Vada (3 pc)", "Crisp, with coconut chutney", 7999),
            ("item_plain_dosa", "Plain Dosa", "Golden crisp, sambar and chutneys", 9999),
            ("item_mysore_dosa", "Mysore Masala Dosa", "Spicy red chutney, potato", 14999),
            ("item_rava_dosa", "Rava Onion Dosa", "Semolina crepe, onions", 13999),
            ("item_uttapam", "Onion Uttapam", "Thick pancake, tomatoes", 11999),
            ("item_pongal", "Ven Pongal", "Rice-lentil comfort, ghee", 10999),
            ("item_payasam", "Pal Payasam", "Rice kheer, cardamom", 8999),
        ],
    },
    {
        "id": "rest_chinese",
        "name": "Dragon Wok",
        "description": "Indo-Chinese favourites",
        "items": [
            ("item_hakka_noodles", "Veg Hakka Noodles", "Smoky wok toss, spring onions", 14999),
            ("item_chicken_noodles", "Chicken Hakka Noodles", "Charred chicken, burnt garlic", 19999),
            ("item_fried_rice", "Veg Fried Rice", "Wok hei, five-spice", 13999),
            ("item_manchurian", "Veg Manchurian", "Crisp veg dumplings, garlic-soy glaze", 16999),
            ("item_chilli_chicken", "Chilli Chicken", "Batter-fried, peppers, soy-chilli toss", 24999),
            ("item_dragon_chicken", "Dragon Chicken", "Fiery red chillies, cashews", 26999),
            ("item_spring_rolls", "Spring Rolls (4 pc)", "Crisp, sweet chilli dip", 12999),
            ("item_momos", "Veg Steamed Momos (8 pc)", "Spicy red chutney", 13999),
            ("item_hot_sour_soup", "Hot & Sour Soup", "Peppery, mushrooms, tofu", 11999),
            ("item_darsaan", "Darsaan with Ice Cream", "Honey-glazed wontons, vanilla scoop", 14999),
        ],
    },
    {
        "id": "rest_burger",
        "name": "Burger Barn",
        "description": "Smash burgers and shakes",
        "items": [
            ("item_classic_smash", "Classic Smash Burger", "Double patty, cheddar, house sauce", 19999),
            ("item_bacon_jam", "Bacon Jam Burger", "Candied bacon, caramelised onions", 27999),
            ("item_paneer_crunch", "Paneer Crunch Burger", "Crisp paneer patty, mint mayo", 17999),
            ("item_mushroom_swiss", "Mushroom Swiss Burger", "Sauteed mushrooms, swiss cheese", 22999),
            ("item_peri_peri", "Peri Peri Chicken Burger", "Flame-grilled, peri mayo", 21999),
            ("item_loaded_fries", "Loaded Cheese Fries", "Cheese sauce, jalapenos, herbs", 14999),
            ("item_peri_fries", "Peri Peri Fries", "Dusted, garlic aioli", 12999),
            ("item_onion_rings", "Beer-battered Onion Rings", "Chipotle dip", 11999),
            ("item_oreo_shake", "Oreo Thickshake", "Cookies and cream, whipped top", 16999),
            ("item_mango_shake", "Alphonso Mango Shake", "Real mango pulp, saffron", 14999),
        ],
    },
    {
        "id": "rest_north",
        "name": "Tandoor Nights",
        "description": "North Indian curries and breads",
        "items": [
            ("item_butter_chicken", "Butter Chicken", "Charred chicken, makhani gravy", 29999),
            ("item_dal_makhani", "Dal Makhani", "48-hour slow-cooked, white butter", 19999),
            ("item_paneer_lababdar", "Paneer Lababdar", "Rich tomato-cashew gravy", 24999),
            ("item_kadhai_veg", "Kadhai Veg", "Charred peppers, kadhai masala", 21999),
            ("item_chole", "Amritsari Chole", "Dark, tangy, anardana", 17999),
            ("item_jeera_rice", "Jeera Rice", "Ghee-tempered cumin rice", 12999),
            ("item_butter_naan", "Butter Naan (2 pc)", "Tandoor-fresh, brushed butter", 7999),
            ("item_garlic_naan", "Garlic Naan (2 pc)", "Roasted garlic, coriander", 9999),
            ("item_laccha_paratha", "Laccha Paratha (2 pc)", "Flaky, whole wheat", 8999),
            ("item_kulfi", "Malai Kulfi", "Dense, pistachio dust", 11999),
        ],
    },
    {
        "id": "rest_sushi",
        "name": "Tokyo Table",
        "description": "Sushi and Japanese bowls",
        "items": [
            ("item_california_roll", "California Roll (8 pc)", "Crabstick, avocado, cucumber", 34999),
            ("item_salmon_nigiri", "Salmon Nigiri (4 pc)", "Norwegian salmon, sushi rice", 39999),
            ("item_veg_maki", "Veg Maki (8 pc)", "Avocado, cucumber, pickled radish", 27999),
            ("item_spicy_tuna", "Spicy Tuna Roll (8 pc)", "Tuna, sriracha mayo, tempura flakes", 37999),
            ("item_chicken_katsu", "Chicken Katsu Curry", "Panko chicken, Japanese curry rice", 32999),
            ("item_veg_ramen", "Veg Shoyu Ramen", "Soy broth, noodles, ajitama egg", 29999),
            ("item_chicken_ramen", "Chicken Ramen", "Rich broth, chashu chicken", 34999),
            ("item_gyoza", "Chicken Gyoza (6 pc)", "Pan-fried, ponzu dip", 24999),
            ("item_edamame", "Spicy Edamame", "Sea salt, togarashi", 14999),
            ("item_mochi", "Mochi Ice Cream (3 pc)", "Mango, chocolate, matcha", 19999),
        ],
    },
    {
        "id": "rest_dessert",
        "name": "Sugar Rush",
        "description": "Desserts and bakes",
        "items": [
            ("item_belgian_truffle", "Belgian Truffle Pastry", "Dark ganache, cocoa sponge", 14999),
            ("item_red_velvet", "Red Velvet Pastry", "Cream cheese frosting", 13999),
            ("item_brownie", "Walnut Brownie", "Served warm", 12999),
            ("item_cheesecake", "Baked Cheesecake", "New York style, berry compote", 19999),
            ("item_cupcake", "Chocolate Cupcakes (4 pc)", "Fudge center", 15999),
            ("item_macarons", "French Macarons (6 pc)", "Assorted flavours", 24999),
            ("item_eclair", "Coffee Eclair", "Choux, coffee cream, glaze", 11999),
            ("item_panna_cotta", "Vanilla Panna Cotta", "Berry coulis", 16999),
            ("item_sizzling_brownie", "Sizzling Brownie", "Hot plate, chocolate sauce", 21999),
            ("item_icecream_sundae", "Classic Sundae", "3 scoops, nuts, wafer", 17999),
        ],
    },
]


def seed():
    init_db()
    session = SessionLocal()
    try:
        # Users
        for email, name, role, password in [
            (CUSTOMER_EMAIL, "Test Customer", "customer", "customer123"),
            (ADMIN_EMAIL, "Test Admin", "admin", "admin123"),
        ]:
            exists = session.execute(select(User).where(User.email == email)).scalar_one_or_none()
            if not exists:
                session.add(User(
                    email=email, name=name, role=role,
                    password_hash=hash_password(password),
                ))
                print(f"created user {email} / {password}")
            else:
                print(f"user exists: {email}")

        # Restaurants + menus
        for r in RESTAURANTS:
            rest = session.execute(
                select(Restaurant).where(Restaurant.id == r["id"])
            ).scalar_one_or_none()
            if not rest:
                rest = Restaurant(id=r["id"], name=r["name"], description=r["description"])
                session.add(rest)
                print(f"created restaurant {r['name']}")
            for item_id, name, desc, price_minor in r["items"]:
                mi = session.execute(
                    select(MenuItem).where(MenuItem.id == item_id)
                ).scalar_one_or_none()
                if not mi:
                    session.add(MenuItem(
                        id=item_id, restaurant_id=r["id"], name=name,
                        description=desc, price_minor=price_minor, currency="INR",
                    ))
        session.commit()
        print("seed complete")
    finally:
        session.close()


if __name__ == "__main__":
    seed()
