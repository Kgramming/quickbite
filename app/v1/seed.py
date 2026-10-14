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
            ("item_chicken_65", "Chicken 65", "Fiery red, curry leaves, yoghurt dip", 22999),
            ("item_prawn_biryani", "Prawn Biryani", "Juicy prawns, saffron rice", 32999),
            ("item_haleem", "Haleem", "Slow-cooked wheat-lentil-meat, ghee", 24999),
            ("item_tangdi_kebab", "Tangdi Kebab (4 pc)", "Smoky drumsticks, charred onions", 25999),
            ("item_mirchi_salan", "Mirchi ka Salan", "Peanut-sesame curry, biryani's best friend", 9999),
            ("item_firni", "Firni", "Rose-kewra rice pudding, pistachio", 11999),
            ("item_keema_biryani", "Keema Biryani", "Spiced minced mutton, saffron rice", 29999),
            ("item_chicken_shawarma", "Chicken Shawarma", "Charred chicken, garlic toum, khubz", 18999),
            ("item_mutton_korma", "Mutton Korma", "Slow-braised, royal mughlai gravy", 32999),
            ("item_shahi_tukda", "Shahi Tukda", "Saffron rabri, fried bread", 14999),
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
            ("item_corn_pizza", "Corn & Cheese Pizza", "Golden corn, extra mozzarella", 32999),
            ("item_farmhouse", "Farmhouse Pizza", "Garden veggies, herbed crust", 34999),
            ("item_cheese_burst", "Cheese Burst Pizza", "Molten cheese core, crispy base", 44999),
            ("item_white_sauce_pasta", "White Sauce Pasta", "Creamy alfredo, exotic veggies", 24999),
            ("item_red_sauce_pasta", "Red Sauce Pasta", "Tangy arrabbiata, basil", 22999),
            ("item_choco_pizza", "Chocolate Pizza", "Nutella base, toasted hazelnuts", 27999),
            ("item_chicken_tikka_pizza", "Chicken Tikka Pizza", "Charred tikka, onions, mint drizzle", 38999),
            ("item_paneer_makhani_pizza", "Paneer Makhani Pizza", "Creamy makhani base, soft paneer", 36999),
            ("item_garlic_knots", "Garlic Knots", "Buttery, parmesan dust", 12999),
            ("item_veggie_paradise", "Veggie Paradise", "Loaded garden veggies, extra cheese", 34999),
        ],
    },
    {
        "id": "rest_dosa",
        "name": "Dosa Diner",
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
            ("item_samosa", "Punjabi Samosa (2 pc)", "Crisp, spiced potato, tamarind dip", 5999),
            ("item_vada_pav", "Vada Pav", "Mumbai classic, garlic chutney", 7999),
            ("item_pav_bhaji", "Pav Bhaji", "Buttery bhaji, toasted pav", 14999),
            ("item_idli_vada", "Idli Vada Combo", "Sambar dip, trio of chutneys", 10999),
            ("item_bisibelebath", "Bisibele Bath", "Karnataka lentil-rice, ghee", 12999),
            ("item_adrak_chai", "Adrak Chai", "Ginger-brewed, cutting style", 4999),
            ("item_masala_vada", "Masala Vada (4 pc)", "Crisp dal fritters, chutney", 7999),
            ("item_kesari_bath", "Kesari Bath", "Saffron semolina halwa, ghee", 8999),
            ("item_tomato_bath", "Tomato Bath", "Tangy tomato rice, peanuts", 10999),
            ("item_neer_dosa", "Neer Dosa (3 pc)", "Lacy rice crepes, coconut chutney", 9999),
        ],
    },
    {
        "id": "rest_chinese",
        "name": "Wok Dynasty",
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
            ("item_chicken_fried_rice", "Chicken Fried Rice", "Smoky wok hei, scallions", 18999),
            ("item_schezwan_noodles", "Schezwan Noodles", "Fiery schezwan toss, peppers", 17999),
            ("item_chicken_momos", "Chicken Steamed Momos (8 pc)", "Juicy, spicy red chutney", 16999),
            ("item_crispy_veg", "Crispy Vegetables", "Batter-crisp, salt-pepper toss", 15999),
            ("item_sweet_corn_soup", "Sweet Corn Soup", "Classic comfort, white pepper", 10999),
            ("item_chicken_lollipop", "Chicken Lollipop (6 pc)", "Frenched wings, schezwan glaze", 23999),
            ("item_chilli_paneer", "Chilli Paneer", "Crisp paneer, peppers, soy-chilli toss", 22999),
            ("item_burnt_garlic_rice", "Burnt Garlic Rice", "Golden garlic, spring onions", 15999),
            ("item_veg_manchow_soup", "Veg Manchow Soup", "Loaded veggies, crisp noodles", 12999),
            ("item_sesame_chicken", "Sesame Chicken", "Honey-soy glaze, toasted sesame", 24999),
        ],
    },
    {
        "id": "rest_burger",
        "name": "Patty House",
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
            ("item_chicken_zinger", "Chicken Zinger Burger", "Crispy fillet, pepper mayo", 19999),
            ("item_veg_crispy", "Veg Crispy Burger", "Crunchy veg patty, tangy mayo", 14999),
            ("item_chicken_popcorn", "Chicken Popcorn", "Bite-size, peri peri dust", 15999),
            ("item_chicken_nuggets", "Chicken Nuggets (8 pc)", "Golden, honey mustard dip", 16999),
            ("item_chicken_roll", "Chicken Tikka Roll", "Flaky paratha, mint mayo", 18999),
            ("item_cold_coffee", "Cold Coffee", "Blended, chocolate drizzle", 12999),
            ("item_double_decker", "Double Decker Burger", "Two patties, triple cheese, special sauce", 24999),
            ("item_corn_cheese_nuggets", "Corn Cheese Nuggets (8 pc)", "Molten cheese core, crispy crumb", 15999),
            ("item_kitkat_shake", "KitKat Thickshake", "Chocolate wafer blend, whipped top", 17999),
            ("item_veggie_strips", "Veggie Strips", "Crunchy veg fingers, peri mayo", 13999),
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
            ("item_chicken_curry", "Homestyle Chicken Curry", "Rustic, garam masala, coriander", 26999),
            ("item_rajma_chawal", "Rajma Chawal", "Kidney beans, steamed basmati", 17999),
            ("item_chole_bhature", "Chole Bhature", "Fluffy bhature, dark chole", 19999),
            ("item_sarson_saag", "Sarson da Saag", "With makki roti, white butter", 21999),
            ("item_rasmalai", "Rasmalai (4 pc)", "Saffron milk, cardamom", 13999),
            ("item_masala_chai", "Masala Chai", "Crushed spices, full-bodied", 5999),
            ("item_dal_tadka", "Dal Tadka", "Ghee tempering, garlic", 15999),
            ("item_malai_kofta", "Malai Kofta", "Creamy cashew gravy, soft koftas", 23999),
            ("item_gajar_halwa", "Gajar ka Halwa", "Slow-cooked carrots, khoya, ghee", 14999),
            ("item_tandoori_roti", "Tandoori Roti (2 pc)", "Whole wheat, clay oven fresh", 5999),
        ],
    },
    {
        "id": "rest_sushi",
        "name": "Sakura Sushi",
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
            ("item_prawn_tempura", "Prawn Tempura (5 pc)", "Crisp batter, tentsuyu dip", 32999),
            ("item_chicken_teriyaki", "Chicken Teriyaki Bowl", "Glazed chicken, steamed rice", 31999),
            ("item_tonkotsu_ramen", "Tonkotsu Ramen", "18-hour pork broth, noodles", 36999),
            ("item_poke_bowl", "Salmon Poke Bowl", "Marinated salmon, sushi rice", 38999),
            ("item_korean_fried", "Korean Fried Chicken", "Gochujang glaze, sesame", 29999),
            ("item_matcha_icecream", "Matcha Ice Cream", "Ceremonial-grade matcha", 17999),
            ("item_salmon_sashimi", "Salmon Sashimi (6 pc)", "Norwegian salmon, wasabi, pickled ginger", 42999),
            ("item_tuna_nigiri", "Tuna Nigiri (4 pc)", "Bluefin tuna, seasoned rice", 41999),
            ("item_dragon_roll", "Dragon Roll (8 pc)", "Prawn tempura, avocado scales", 39999),
            ("item_miso_soup", "Miso Soup", "Tofu, wakame, scallions", 12999),
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
            ("item_white_choc_cake", "White Chocolate Cake", "Silky white ganache, vanilla sponge", 22999),
            ("item_chocolate_cake", "Chocolate Truffle Cake", "Dark truffle, cocoa nib", 19999),
            ("item_kaju_barfi", "Kaju Barfi (8 pc)", "Silver leaf, cardamom", 24999),
            ("item_besan_ladoo", "Besan Ladoo (8 pc)", "Ghee-roasted, melt-in-mouth", 18999),
            ("item_tender_coconut", "Tender Coconut Ice Cream", "Malai chunks, coconut cream", 16999),
            ("item_dark_choc_sundae", "Dark Chocolate Sundae", "70% dark, roasted nuts", 19999),
            ("item_rasmalai_cake", "Rasmalai Cake", "Saffron milk soak, cardamom cream", 23999),
            ("item_motichoor_ladoo", "Motichoor Ladoo (8 pc)", "Fine boondi pearls, ghee", 17999),
            ("item_jalebi_rabri", "Jalebi with Rabri", "Crisp saffron jalebi, thick rabri", 14999),
            ("item_butterscotch_pastry", "Butterscotch Pastry", "Caramel crunch, praline", 15999),
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
            else:
                # Keep name/description in sync so renames apply on re-seed.
                if rest.name != r["name"] or rest.description != r["description"]:
                    print(f"renamed restaurant {rest.name} -> {r['name']}")
                    rest.name = r["name"]
                    rest.description = r["description"]
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
