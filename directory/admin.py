from django.contrib import admin

from .models import Category, Provider


@admin.register(Category)
class CategoryAdmin(admin.ModelAdmin):
    search_fields = ["name"]


@admin.register(Provider)
class ProviderAdmin(admin.ModelAdmin):
    list_display = ["name", "category", "city", "phone", "is_approved", "created_at"]
    list_filter = ["is_approved", "category", "city"]
    list_editable = ["is_approved"]
    search_fields = ["name", "city", "phone"]
    actions = ["approve"]

    @admin.action(description="Valider les prestataires sélectionnés")
    def approve(self, request, queryset):
        updated = queryset.update(is_approved=True)
        self.message_user(request, f"{updated} prestataire(s) validé(s).")
