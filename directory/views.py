from django.db.models import Q
from django.urls import reverse_lazy
from django.views.generic import CreateView, DetailView, ListView, TemplateView

from .forms import ProviderForm
from .models import Category, Provider


class ProviderListView(ListView):
    paginate_by = 12
    context_object_name = "providers"

    def get_queryset(self):
        qs = Provider.objects.filter(is_approved=True).select_related("category")
        q = self.request.GET.get("q", "").strip()
        category = self.request.GET.get("category", "")
        city = self.request.GET.get("city", "").strip()

        if q:
            qs = qs.filter(Q(name__icontains=q) | Q(description__icontains=q))
        if category.isdigit():
            qs = qs.filter(category_id=category)
        if city:
            qs = qs.filter(city__iexact=city)
        return qs

    def get_context_data(self, **kwargs):
        ctx = super().get_context_data(**kwargs)
        ctx["categories"] = Category.objects.all()
        ctx["cities"] = (
            Provider.objects.filter(is_approved=True)
            .order_by("city")
            .values_list("city", flat=True)
            .distinct()
        )
        # Keep the filters when moving between pages
        params = self.request.GET.copy()
        params.pop("page", None)
        ctx["querystring"] = params.urlencode()
        return ctx


class ProviderDetailView(DetailView):
    queryset = Provider.objects.filter(is_approved=True).select_related("category")
    context_object_name = "provider"


class ProviderCreateView(CreateView):
    form_class = ProviderForm
    template_name = "directory/provider_form.html"
    success_url = reverse_lazy("directory:thanks")


class ThanksView(TemplateView):
    template_name = "directory/thanks.html"
