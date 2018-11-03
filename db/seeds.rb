# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)
Project.destroy_all
User.destroy_all
Role.destroy_all

r2 = Role.create({name: "Developer", description: "Can read and create items. Can update and destroy own items"})
r3 = Role.create({name: "Manager", description: "Can perform any CRUD operation on any resource"})

u2 = User.create({name: "Sue", email: "sue@example.com", password: "aaaaaaaa", password_confirmation: "aaaaaaaa", role_id: r2.id})
u3 = User.create({name: "Kev", email: "kev@example.com", password: "aaaaaaaa", password_confirmation: "aaaaaaaa", role_id: r2.id})
u4 = User.create({name: "Manager", email: "manager@example.com", password: "manager", password_confirmation: "aaaaaaaa", role_id: r3.id})

i1 = Project.create({name: "Rayban Sunglasses", description: "Stylish shades",  user_id: u2.id})
i2 = Project.create({name: "Gucci watch", description: "Expensive timepiece",  user_id: u2.id})
i3 = Project.create({name: "Henri Lloyd Pullover", description: "Classy knitwear", user_id: u3.id})
i4 = Project.create({name: "Porsche socks", description: "Cosy footwear", user_id: u3.id})