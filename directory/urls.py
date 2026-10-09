from django.urls import path

from . import views

app_name = "directory"

urlpatterns = [
    path("", views.ProviderListView.as_view(), name="list"),
    path("proposer/", views.ProviderCreateView.as_view(), name="submit"),
    path("merci/", views.ThanksView.as_view(), name="thanks"),
    path("<int:pk>/", views.ProviderDetailView.as_view(), name="detail"),
]
